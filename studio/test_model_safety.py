"""Configuration and profile input checks; fixtures never touch live settings."""
import json,os,re
from pathlib import Path
import pytest
from model import DEFAULTS,Profiles,ConfigStore


def test_managed_defaults_match_runtime():
    runtime_settings=os.environ.get('LATTO_RUNTIME_SETTINGS')
    if not runtime_settings:
        pytest.skip('Set LATTO_RUNTIME_SETTINGS to the compatible shell’s Settings.qml.')
    source=Path(runtime_settings).read_text()
    runtime={}
    for kind,key,value in re.findall(r'property (\w+) (\w+): ([^\n]+)',source):
        try:runtime[key]=json.loads(value)
        except ValueError:pass
    for key,value in DEFAULTS.items():
        assert key in runtime,key
        assert runtime[key]==value,key


@pytest.mark.parametrize('constant',['NaN','Infinity','-Infinity'])
def test_nonfinite_config_is_rejected_without_write(tmp_path,constant):
    path=tmp_path/'config.json';path.write_text('{"unmanaged":'+constant+'}')
    before=path.read_bytes()
    with pytest.raises(ValueError,match='finite'):
        ConfigStore(path,tmp_path/'backups')
    assert path.read_bytes()==before


@pytest.mark.parametrize('version',[True,False,'1',1.0,2])
def test_profiles_require_integer_supported_version(tmp_path,version):
    path=tmp_path/'profile.json'
    path.write_text(json.dumps(dict(format='latto-studio',version=version,settings={'idleWidth':260})))
    with pytest.raises(ValueError,match='version 1'):
        Profiles.read(path)


def test_profile_fifo_is_rejected_without_blocking(tmp_path):
    path=tmp_path/'profile.json';os.mkfifo(path)
    with pytest.raises(ValueError,match='regular'):
        Profiles.read(path)


def test_profile_size_limit_is_enforced(tmp_path):
    path=tmp_path/'profile.json';path.write_text(' '*131073)
    with pytest.raises(ValueError,match='large'):
        Profiles.read(path)


def test_profile_unicode_roundtrip(tmp_path):
    path=tmp_path/'profile.json'
    Profiles.export(path,{'fontFamily':'Noto Sans देवनागरी','idleWidth':280})
    assert Profiles.read(path)['fontFamily']=='Noto Sans देवनागरी'
    assert path.stat().st_mode&0o777==0o600


def test_profile_accepts_utf8_byte_order_mark(tmp_path):
    path=tmp_path/'profile.json'
    path.write_bytes(b'\xef\xbb\xbf'+json.dumps({'format':'latto-studio','version':1,'settings':{'idleWidth':280}}).encode())
    assert Profiles.read(path)['idleWidth']==280
