"""Offline contract tests for HTTP range ZIP extraction (not a network claim)."""
from pathlib import Path
import io,random,subprocess,tempfile,unittest,zipfile
from unittest.mock import patch
from extract_official_web_template import CurlRangeZip,RangeUnsupported

def archive_bytes():
    inner=io.BytesIO()
    with zipfile.ZipFile(inner,'w',zipfile.ZIP_DEFLATED)as archive:
        archive.writestr('godot.wasm',random.Random(371).randbytes(12000))
        archive.writestr('godot.js','console.log("range fixture");')
    desired=inner.getvalue();outer=io.BytesIO()
    with zipfile.ZipFile(outer,'w',zipfile.ZIP_STORED)as archive:
        archive.writestr('templates/version.txt','4.7.2.stable')
        archive.writestr('templates/web_nothreads_release.zip',desired)
        archive.writestr('templates/linux_release.x86_64',random.Random(281).randbytes(2*1024*1024))
    return outer.getvalue(),desired

class RemoteZipContractTests(unittest.TestCase):
    def fake_curl(self,source,without_content_range=False,wrong_body=False):
        def run(command,**_kwargs):
            requested=command[command.index('--range')+1]
            if requested.startswith('-'):start=max(0,len(source)-int(requested[1:]));end=len(source)-1
            else:start,end=map(int,requested.split('-'))
            headers=Path(command[command.index('--dump-header')+1]);body=Path(command[command.index('--output')+1])
            suffix=''if without_content_range else f'Content-Range: bytes {start}-{end}/{len(source)}\r\n'
            headers.write_text('HTTP/2 206\r\n'+suffix+'\r\n')
            body.write_bytes(source[start:end+1]+(b'bad'if wrong_body else b''))
            return subprocess.CompletedProcess(command,0,'','')
        return run
    def test_crc_checked_only_desired_member_without_full_archive_download(self):
        source,desired=archive_bytes()
        with tempfile.TemporaryDirectory()as folder,patch('extract_official_web_template.subprocess.run',self.fake_curl(source)):
            remote=CurlRangeZip('https://github.com/test/templates.tpz',folder)
            with zipfile.ZipFile(remote)as archive:actual=archive.read('templates/web_nothreads_release.zip')
            self.assertEqual(actual,desired)
            self.assertLess(sum(r['received_bytes']for r in remote.requests),100000)
            self.assertEqual(remote.size,len(source))
    def test_missing_content_range_rejects_full_response(self):
        source,_=archive_bytes()
        with tempfile.TemporaryDirectory()as folder,patch('extract_official_web_template.subprocess.run',self.fake_curl(source,without_content_range=True)):
            with self.assertRaises(RangeUnsupported):CurlRangeZip('https://github.com/test/templates.tpz',folder)
    def test_wrong_body_length_rejected(self):
        source,_=archive_bytes()
        with tempfile.TemporaryDirectory()as folder,patch('extract_official_web_template.subprocess.run',self.fake_curl(source,wrong_body=True)):
            with self.assertRaises(RangeUnsupported):CurlRangeZip('https://github.com/test/templates.tpz',folder)
    def test_curl_failure_rejects_without_retrying_full_download(self):
        with tempfile.TemporaryDirectory()as folder,patch('extract_official_web_template.subprocess.run',return_value=subprocess.CompletedProcess([],63,'','Maximum file size exceeded'))as mock:
            with self.assertRaises(RangeUnsupported):CurlRangeZip('https://github.com/test/templates.tpz',folder)
            self.assertEqual(mock.call_count,1)

if __name__=='__main__':unittest.main(verbosity=2)
