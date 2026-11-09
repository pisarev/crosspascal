import argparse
import configparser
from contextlib import contextmanager
import ctypes
from ctypes import wintypes
import getpass
import hashlib
import http.client
import json
import os
from pathlib import Path, PurePosixPath
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
import xml.etree.ElementTree as XML


VERIFIED_PACKAGES = {}
GITHUB_RELEASES = {}
GITHUB_AUTH_ATTEMPTED = False


class Credential(ctypes.Structure):
    _fields_ = [('Flags', wintypes.DWORD), ('Type', wintypes.DWORD),
        ('TargetName', wintypes.LPWSTR), ('Comment', wintypes.LPWSTR),
        ('LastWritten', wintypes.FILETIME), ('CredentialBlobSize', wintypes.DWORD),
        ('CredentialBlob', ctypes.POINTER(ctypes.c_ubyte)), ('Persist', wintypes.DWORD),
        ('AttributeCount', wintypes.DWORD), ('Attributes', ctypes.c_void_p),
        ('TargetAlias', wintypes.LPWSTR), ('UserName', wintypes.LPWSTR)]


def credential_api():
    api = ctypes.WinDLL('advapi32', use_last_error=True)
    api.CredReadW.argtypes = [wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD,
        ctypes.POINTER(ctypes.POINTER(Credential))]
    api.CredReadW.restype = wintypes.BOOL
    api.CredWriteW.argtypes = [ctypes.POINTER(Credential), wintypes.DWORD]
    api.CredWriteW.restype = wintypes.BOOL
    api.CredFree.argtypes = [ctypes.c_void_p]
    api.CredFree.restype = None
    return api


def read_saved_token(target='CrossPascal/GitHub/pisarev'):
    api = credential_api()
    pointer = ctypes.POINTER(Credential)()
    if not api.CredReadW(target, 1, 0, ctypes.byref(pointer)):
        if ctypes.get_last_error() == 1168:
            return None
        raise ctypes.WinError(ctypes.get_last_error())
    try:
        return ctypes.string_at(pointer.contents.CredentialBlob,
            pointer.contents.CredentialBlobSize).decode('utf-16le')
    finally:
        api.CredFree(pointer)


def save_token(token, target='CrossPascal/GitHub/pisarev'):
    data = token.encode('utf-16le')
    buffer = (ctypes.c_ubyte * len(data)).from_buffer_copy(data)
    credential = Credential(Type=1, TargetName=target, CredentialBlobSize=len(data),
        CredentialBlob=buffer, Persist=2, UserName='github.com')
    api = credential_api()
    if not api.CredWriteW(ctypes.byref(credential), 0):
        raise ctypes.WinError(ctypes.get_last_error())


def github_authentication():
    if os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN'):
        return
    gh = shutil.which('gh')
    if gh:
        result = subprocess.run([gh, 'auth', 'token', '--hostname', 'github.com'], capture_output=True, text=True)
        if result.returncode == 0 and result.stdout.strip():
            os.environ['GH_TOKEN'] = result.stdout.strip()
            return
    saved = read_saved_token()
    if saved:
        os.environ['GH_TOKEN'] = saved
        return
    print('GitHub did not allow an anonymous request. The release may be private or the public request limit may be reached.')
    print('Public releases do not normally need a token. To retry with your account, use a token with read access.')
    print('A fine-grained token needs this repository selected and Contents: Read-only.')
    token = getpass.getpass('GitHub token (hidden input): ').strip()
    if not token:
        raise RuntimeError('Authenticated retry cancelled. Public downloads normally need no token; check the release URL or try again after the GitHub request limit resets.')
    os.environ['GH_TOKEN'] = token
    with open_url('https://api.github.com/repos/pisarev/crosspascal', {'Accept': 'application/vnd.github+json'}) as response:
        json.load(response)
    if input('Remember it in Windows Credential Manager for other examples? [y/N] ').strip().lower() == 'y':
        save_token(token)
        print('Saved as CrossPascal/GitHub/pisarev in Windows Credential Manager.')


@contextmanager
def preparation_lock(cache):
    import msvcrt
    cache.mkdir(parents=True, exist_ok=True)
    with (cache / '.prepare.lock').open('a+b') as stream:
        if stream.tell() == 0:
            stream.write(b'0')
            stream.flush()
        stream.seek(0)
        try:
            msvcrt.locking(stream.fileno(), msvcrt.LK_NBLCK, 1)
        except OSError:
            raise RuntimeError('Another preparation is using this download folder. Wait for it to finish and try again.') from None
        try:
            yield
        finally:
            stream.seek(0)
            msvcrt.locking(stream.fileno(), msvcrt.LK_UNLCK, 1)


class DownloadRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, response, code, message, headers, url):
        redirected = super().redirect_request(request, response, code, message, headers, url)
        if redirected is not None:
            if urllib.parse.urlsplit(url).scheme != 'https':
                raise RuntimeError('A download redirected to an insecure address.')
            if urllib.parse.urlsplit(url).hostname != 'api.github.com':
                redirected.remove_header('Authorization')
        return redirected


def file_hash(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def open_url(url, headers=None):
    global GITHUB_AUTH_ATTEMPTED
    values = {'User-Agent': 'CrossPascal-Prepare', 'Accept-Encoding': 'identity'}
    values.update(headers or {})
    if urllib.parse.urlsplit(url).hostname == 'api.github.com':
        token = os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN')
        if token:
            values['Authorization'] = 'Bearer ' + token
    request = urllib.request.Request(url, headers=values)
    try:
        return urllib.request.build_opener(DownloadRedirect()).open(request, timeout=90)
    except urllib.error.HTTPError as error:
        if error.code in (401, 403, 404) and urllib.parse.urlsplit(url).hostname == 'api.github.com':
            if not values.get('Authorization') and not GITHUB_AUTH_ATTEMPTED:
                GITHUB_AUTH_ATTEMPTED = True
                error.close()
                github_authentication()
                return open_url(url, headers)
            raise RuntimeError('GitHub did not grant access. Check the release URL, account access and token permissions, or wait for its request limit to reset.') from None
        raise


def asset_url(asset):
    if 'url' in asset:
        headers = {'Accept': 'application/octet-stream'} if urllib.parse.urlsplit(asset['url']).hostname == 'api.github.com' else {}
        return asset['url'], headers
    url = 'https://api.github.com/repos/' + asset['repository'] + '/releases/tags/' + asset['release']
    if url not in GITHUB_RELEASES:
        with open_url(url, {'Accept': 'application/vnd.github+json'}) as response:
            GITHUB_RELEASES[url] = json.load(response)
    release = GITHUB_RELEASES[url]
    matches = [row for row in release['assets'] if row['name'] == asset['name']]
    if len(matches) != 1 or matches[0]['size'] != asset['bytes']:
        raise RuntimeError('The release does not contain the expected asset: ' + asset['name'])
    if not (os.environ.get('GH_TOKEN') or os.environ.get('GITHUB_TOKEN')) and matches[0].get('browser_download_url'):
        return matches[0]['browser_download_url'], {}
    return matches[0]['url'], {'Accept': 'application/octet-stream'}


def download(asset, cache):
    cache.mkdir(parents=True, exist_ok=True)
    path = cache / asset['name']
    if path.is_file() and path.stat().st_size == asset['bytes'] and file_hash(path) == asset['sha256']:
        print('Verified cached file: ' + path.name, flush=True)
        return path
    partial = cache / (asset['name'] + '.partial')
    url, headers = asset_url(asset)
    for attempt in range(3):
        start = partial.stat().st_size if partial.exists() else 0
        if start > asset['bytes']:
            partial.unlink()
            start = 0
        if start == asset['bytes']:
            if file_hash(partial) != asset['sha256']:
                partial.unlink()
                raise RuntimeError('A completed download failed SHA-256 verification: ' + path.name)
            partial.replace(path)
            return path
        request_headers = dict(headers)
        if start:
            request_headers['Range'] = 'bytes=' + str(start) + '-'
        print(('Resuming ' if start else 'Downloading ') + path.name + ' (' + str(asset['bytes']) + ' bytes)', flush=True)
        try:
            with open_url(url, request_headers) as response:
                status = response.getcode()
                append = start > 0 and status == 206
                if status == 206 and not response.headers.get('Content-Range', '').startswith('bytes ' + str(start) + '-'):
                    raise RuntimeError('The server returned an unexpected download range.')
                if status not in (200, 206):
                    raise RuntimeError('Unexpected download status: ' + str(status))
                completed = start if append else 0
                last_progress = time.monotonic()
                with partial.open('ab' if append else 'wb') as output:
                    while block := response.read(1024 * 1024):
                        completed += len(block)
                        if completed > asset['bytes']:
                            raise RuntimeError('A download exceeds its declared size.')
                        output.write(block)
                        if time.monotonic() - last_progress >= 3:
                            print('  ' + str(completed * 100 // asset['bytes']) + '%', flush=True)
                            last_progress = time.monotonic()
            if partial.stat().st_size != asset['bytes']:
                raise OSError('The download ended before all bytes arrived.')
            if file_hash(partial) != asset['sha256']:
                partial.unlink()
                raise RuntimeError('SHA-256 verification failed: ' + path.name)
            partial.replace(path)
            return path
        except (OSError, urllib.error.URLError, http.client.HTTPException):
            if attempt == 2:
                raise RuntimeError('Download interrupted; run Prepare.cmd again to resume ' + path.name) from None
            print('Connection interrupted; retrying.', flush=True)
            time.sleep(2)
    raise RuntimeError('Download could not be completed.')


def safe_member(name):
    path = PurePosixPath(name.replace('\\', '/'))
    if not path.parts or path.is_absolute() or '..' in path.parts or ':' in name:
        raise RuntimeError('An archive contains an unsafe path.')
    return path


def extract_zip(archive, destination):
    with zipfile.ZipFile(archive) as package:
        for member in package.infolist():
            safe_member(member.filename)
            if (member.external_attr >> 16) & 0o170000 == 0o120000:
                raise RuntimeError('Archive links are not supported.')
        package.extractall(destination)


def extract_package(package, assets, cache, installed, sevenzip):
    destination = installed / package['directory']
    receipt = installed / '.receipts' / (package['id'] + '.json')
    identity = {name: assets[name]['sha256'] for name in package['assets']}
    if VERIFIED_PACKAGES.get(str(destination)) == identity:
        return destination
    if receipt.is_file() and json.loads(receipt.read_text(encoding='utf-8')).get('assets') == identity:
        files = json.loads(receipt.read_text(encoding='utf-8'))['files']
        print('Checking installed package: ' + package['title'], flush=True)
        valid = True
        editable = set(package.get('editable', []))
        for name, pin in files.items():
            path = destination / name
            same = path.is_file() and path.stat().st_size == pin['bytes'] and file_hash(path) == pin['sha256']
            if not same:
                if name in editable and path.is_file():
                    print('Preserved local changes: ' + name, flush=True)
                else:
                    valid = False
                    break
        if valid:
            VERIFIED_PACKAGES[str(destination)] = identity
            return destination
        raise RuntimeError('Prepared files have changed. Preserve your work and choose a new installation folder: ' + str(destination))
    if destination.exists():
        raise RuntimeError('The destination already exists without a matching receipt: ' + str(destination))
    paths = [download(assets[name], cache) for name in package['assets']]
    workspace = installed / ('.extract-' + package['id'])
    marker = installed / ('.extract-' + package['id'] + '.owner.json')
    if workspace.exists():
        if (workspace.resolve().parent != installed.resolve() or workspace.is_symlink() or workspace.is_junction()
                or not marker.is_file() or json.loads(marker.read_text(encoding='utf-8')) != identity):
            raise RuntimeError('An unrecognized extraction folder already exists: ' + str(workspace))
        print('Restarting the interrupted extraction: ' + package['title'], flush=True)
        shutil.rmtree(workspace)
    marker.write_text(json.dumps(identity), encoding='utf-8')
    workspace.mkdir(parents=True)
    print('Extracting ' + package['title'] + '...', flush=True)
    try:
        if package.get('format') == 'file':
            shutil.copyfile(paths[0], workspace / paths[0].name)
        elif paths[0].suffix.lower() == '.zip':
            extract_zip(paths[0], workspace)
        else:
            tool_environment = {key: value for key, value in os.environ.items() if key not in ('GH_TOKEN', 'GITHUB_TOKEN')}
            listing = subprocess.run([str(sevenzip), 'l', '-slt', str(paths[0])], capture_output=True, text=True, errors='replace', env=tool_environment)
            if listing.returncode:
                raise RuntimeError('Could not read the model archive.')
            contents = listing.stdout.split('----------', 1)
            if len(contents) != 2:
                raise RuntimeError('Could not validate model archive paths.')
            for line in contents[1].splitlines():
                if line.startswith('Path = '):
                    safe_member(line[7:])
                if line.startswith(('Symbolic Link = ', 'Hard Link = ')):
                    raise RuntimeError('Archive links are not supported.')
            result = subprocess.run([str(sevenzip), 'x', '-y', '-o' + str(workspace), str(paths[0])], capture_output=True, env=tool_environment)
            if result.returncode:
                raise RuntimeError('Could not extract the model archive. Check free disk space.')
        source = workspace / package.get('archive_root', '')
        if not source.is_dir():
            raise RuntimeError('The expected package directory is missing.')
        files = {p.relative_to(source).as_posix(): {'bytes': p.stat().st_size, 'sha256': file_hash(p)}
                 for p in source.rglob('*') if p.is_file()}
        for required in package.get('required', []):
            if required not in files:
                raise RuntimeError('A required package file is missing: ' + required)
        destination.parent.mkdir(parents=True, exist_ok=True)
        source.replace(destination)
        if workspace.exists() and workspace != source:
            workspace.rmdir()
        receipt.parent.mkdir(parents=True, exist_ok=True)
        receipt.write_text(json.dumps({'assets': identity, 'files': files}, indent=2), encoding='utf-8')
        marker.unlink()
        VERIFIED_PACKAGES[str(destination)] = identity
        return destination
    except Exception:
        print('Incomplete files are retained at ' + str(workspace), flush=True)
        raise


def prepare_example(example, manifest, installed, cache):
    assets = manifest['assets']
    packages = manifest['packages']
    required = example['packages']
    needed = sum(assets[name]['bytes'] for key in required for name in packages[key]['assets']
                 if not (cache / assets[name]['name']).exists())
    extraction = sum(packages[key]['extracted_bytes'] for key in required
                     if not (installed / packages[key]['directory']).exists())
    installed.mkdir(parents=True, exist_ok=True)
    if shutil.disk_usage(installed).free < needed + extraction + 1024 ** 3:
        raise RuntimeError('Not enough disk space. Allow ' + str((needed + extraction) // 1024 ** 3 + 1) + ' GiB for this example.')
    print('\nPreparing ' + example['title'], flush=True)
    print('Download size for missing files: ' + str(round(needed / 1024 ** 3, 2)) + ' GiB', flush=True)
    print(example.get('requirements', ''), flush=True)
    sevenzip = None
    if any(packages[key]['assets'][0].endswith('.001') for key in required):
        sevenzip = download(manifest['sevenzip'], cache)
    paths = {}
    for key in required:
        paths[key] = extract_package(packages[key], assets, cache, installed, sevenzip)
    sdk = paths['sdk']
    for key in required:
        if 'overlay' in packages[key]:
            for relative in packages[key]['overlay']:
                source = paths[key] / relative
                target = sdk / relative
                if target.exists():
                    if file_hash(target) != file_hash(source):
                        raise RuntimeError('A dependency would overwrite a different file: ' + str(target))
                else:
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(source, target)
    project = sdk / example['project']
    if not project.with_suffix('.dproj').is_file() or not project.with_suffix('.lpi').is_file():
        raise RuntimeError('The project files are missing from the installed SDK.')
    values = {'sdk': str(sdk)}
    for key, value in example.get('defaults', {}).items():
        for package_id, directory in paths.items():
            value = value.replace('{' + package_id + '}', str(directory))
        values[key] = value
    config = configparser.ConfigParser(interpolation=None)
    config['example'] = values
    outputs = [project.parent]
    delphi = XML.parse(project.with_suffix('.dproj'))
    for node in delphi.iter():
        if node.tag.split('}')[-1] == 'DCC_ExeOutput' and node.text:
            output = node.text.replace('$(Platform)', 'Win64').replace('$(Config)', 'Release').replace('\\', '/')
            outputs.append((project.parent / output).resolve())
            break
    lazarus = XML.parse(project.with_suffix('.lpi'))
    target = lazarus.find('./CompilerOptions/Target/Filename')
    if target is not None:
        outputs.append((project.parent / target.attrib['Value'].replace('\\', '/')).parent.resolve())
    defaults = []
    for directory in dict.fromkeys(outputs):
        directory.mkdir(parents=True, exist_ok=True)
        ini = directory / (project.name + '.prepared.ini')
        if not ini.exists():
            with ini.open('w', encoding='utf-8') as output:
                config.write(output)
        defaults.append(str(ini))
        for relative in example.get('app_local', []):
            source = sdk / relative
            target = directory / source.name
            if target.exists():
                if file_hash(target) != file_hash(source):
                    raise RuntimeError('A different app-local runtime file already exists: ' + str(target))
            else:
                shutil.copyfile(source, target)
    (sdk / 'results').mkdir(exist_ok=True)
    print('\nREADY: ' + example['title'], flush=True)
    print('Delphi 13.2: open ' + str(project.with_suffix('.dproj')), flush=True)
    print('Lazarus 4.8: open ' + str(project.with_suffix('.lpi')), flush=True)
    print('Build for Windows 64-bit, then Run. ' + example.get('next', ''), flush=True)
    print('Keep this prepared folder together. Downloaded models and libraries are shared with other examples.', flush=True)
    return {'example': example['id'], 'project': str(project), 'defaults': defaults, 'status': 'READY'}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--manifest', type=Path, default=Path(__file__).with_name('prepare-manifest.json'))
    parser.add_argument('--release', default='early-access-017')
    parser.add_argument('--example')
    parser.add_argument('--home', type=Path)
    parser.add_argument('--cache', type=Path)
    parser.add_argument('--all', action='store_true')
    options = parser.parse_args()
    if options.manifest.is_file():
        manifest = json.loads(options.manifest.read_text(encoding='utf-8-sig'))
    else:
        endpoint = 'https://api.github.com/repos/pisarev/crosspascal/releases/tags/' + options.release
        with open_url(endpoint, {'Accept': 'application/vnd.github+json'}) as response:
            release = json.load(response)
        candidates = [row for row in release['assets'] if row['name'] == 'PREPARE-MANIFEST.json']
        if len(candidates) != 1 or candidates[0]['size'] > 2 * 1024 ** 2:
            raise RuntimeError('The release preparation manifest is missing or invalid.')
        with open_url(candidates[0]['url'], {'Accept': 'application/octet-stream'}) as response:
            manifest = json.loads(response.read(2 * 1024 ** 2 + 1))
    if manifest.get('schema') != 'crosspascal.prepare.v1' or manifest.get('release') != options.release:
        raise RuntimeError('The preparation manifest belongs to a different release.')
    installed = options.home or Path(os.environ.get('CROSSPASCAL_PREPARE_HOME') or
        str(Path(os.environ['LOCALAPPDATA']) / 'CrossPascal' / manifest['release']))
    cache = options.cache or installed.parent / 'downloads'
    examples = manifest['examples']
    if options.all:
        selected = examples
    else:
        chosen = options.example
        if not chosen:
            for index, row in enumerate(examples, 1):
                print(str(index) + '. ' + row['title'])
            chosen = input('Choose an example: ').strip()
            if chosen.isdecimal() and 1 <= int(chosen) <= len(examples):
                chosen = examples[int(chosen) - 1]['id']
        selected = [row for row in examples if row['id'] == chosen]
        if not selected:
            raise RuntimeError('Choose a listed example.')
    for example in selected:
        for package_id in example['packages']:
            package = manifest['packages'][package_id]
            if package.get('license_notice'):
                print(package['title'] + ': ' + package['license_notice'], flush=True)
                print('Terms: ' + package['license_url'], flush=True)
    with preparation_lock(cache):
        results = [prepare_example(row, manifest, installed, cache) for row in selected]
    report = installed / 'prepare-result.json'
    report.write_text(json.dumps({'release': manifest['release'], 'examples': results}, indent=2), encoding='utf-8')
    if len(results) == 1 and os.environ.get('CROSSPASCAL_PREPARE_NO_OPEN') != '1':
        os.startfile(str(Path(results[0]['project']).parent))


if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print('\nPreparation cancelled. Partial downloads will be resumed next time.', file=sys.stderr)
        sys.exit(130)
    except Exception as error:
        print('\nPreparation failed: ' + str(error), file=sys.stderr)
        sys.exit(1)
