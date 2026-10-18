"""Extract only an official web template using validated HTTP byte ranges.

Uses the system curl certificate store, not Python urllib's CA configuration.
Refuses HTTP 200/full downloads; the caller can choose a full TPZ download.
ZIP member CRC and downloaded member SHA256 are checked/recorded. The full
official TPZ SHA256 cannot be checked without downloading the entire TPZ.
"""
from pathlib import Path
import argparse,hashlib,io,json,re,subprocess,tempfile,time,urllib.parse,zipfile

URL='https://api.github.com/repos/godotengine/godot-builds/releases/assets/519674520'
MEMBER='templates/web_nothreads_release.zip'
OFFICIAL_TPZ_SHA256='f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011'

class RangeUnsupported(RuntimeError):pass

class CurlRangeZip(io.RawIOBase):
    def __init__(self,url,folder):
        self.url=url;self.folder=Path(folder);self.position=0;self.requests=[];self.cache=[]
        data,start,end,total=self._request(None,None)
        self.size=total;self.cache.append((start,data))
    def readable(self):return True
    def seekable(self):return True
    def tell(self):return self.position
    def seek(self,offset,whence=io.SEEK_SET):
        self.position=offset if whence==io.SEEK_SET else self.position+offset if whence==io.SEEK_CUR else self.size+offset
        if self.position<0:raise ValueError('Negative ZIP seek')
        return self.position
    def read(self,size=-1):
        if size<0:size=self.size-self.position
        size=min(size,self.size-self.position)
        if size<=0:return b''
        if size>128*1024*1024:raise RangeUnsupported('Refusing a range larger than128MiB; no whole-TPZ fallback')
        for start,data in self.cache:
            relative=self.position-start
            if relative>=0 and relative+size<=len(data):
                self.position+=size;return data[relative:relative+size]
        start=self.position;end=start+size-1
        data,actual_start,actual_end,total=self._request(start,end)
        if total!=self.size or actual_start!=start or actual_end!=end:raise RangeUnsupported('Range response changed ZIP size or returned wrong bytes')
        self.cache.append((start,data));self.position+=len(data);return data
    def _request(self,start,end):
        request_range='1281284145-1281349701' if start is None else f'{start}-{end}'
        cap=1114112 if start is None else end-start+1+1024
        prefix=self.folder/f'range-{len(self.requests):02}'
        headers=prefix.with_suffix('.headers');body=prefix.with_suffix('.bin')
        # Distinct query avoids intermediaries reusing a previous different range.
        parts=urllib.parse.urlsplit(self.url)
        query=urllib.parse.parse_qsl(parts.query,keep_blank_values=True)+[('codex_zip_range',request_range)]
        url=urllib.parse.urlunsplit((parts.scheme,parts.netloc,parts.path,urllib.parse.urlencode(query),parts.fragment))
        command=['curl','--silent','--show-error','--fail','--location','--retry','1','--connect-timeout','15','--max-time','600','--max-filesize',str(cap),'--header','Accept: application/octet-stream','--header','Accept-Encoding: identity','--header','Cache-Control: no-cache','--range',request_range,'--dump-header',str(headers),'--output',str(body),url]
        run=subprocess.run(command,capture_output=True,text=True)
        if run.returncode:
            raise RangeUnsupported(f'curl range {request_range} failed ({run.returncode}): {run.stderr.strip()}')
        header_text=headers.read_text(errors='replace')
        matches=re.findall(r'^content-range:\s*bytes\s+(\d+)-(\d+)/(\d+)\s*$',header_text,re.I|re.M)
        if not matches:raise RangeUnsupported('Official server did not provide Content-Range; refusing a full-body download')
        actual_start,actual_end,total=map(int,matches[-1]);data=body.read_bytes()
        if len(data)!=actual_end-actual_start+1:raise RangeUnsupported('Range body length mismatch')
        self.requests.append({'requested':request_range,'start':actual_start,'end':actual_end,'total':total,'received_bytes':len(data)})
        return data,actual_start,actual_end,total

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--output-dir',type=Path,default=Path(__file__).resolve().parent/'official-web-template');args=parser.parse_args()
    args.output_dir.mkdir(parents=True,exist_ok=True)
    began=time.monotonic()
    try:
        with tempfile.TemporaryDirectory(prefix='official-godot-ranges-',dir=args.output_dir)as temp:
            remote=CurlRangeZip(URL,temp)
            with zipfile.ZipFile(remote)as archive:
                names=archive.namelist()
                matches=[n for n in names if n==MEMBER or n.endswith('/web_nothreads_release.zip')or n=='web_nothreads_release.zip']
                if len(matches)!=1:raise RangeUnsupported('Expected exactly one official single-thread release member; found '+repr(matches))
                info=archive.getinfo(matches[0]);data=archive.read(info)
            target=args.output_dir/'web_nothreads_release.zip';target.write_bytes(data)
            with zipfile.ZipFile(target)as inner:
                if inner.testzip()is not None:raise RangeUnsupported('Extracted template failed internal ZIP CRC')
                inner_names=inner.namelist()
                if not any(n.endswith('.wasm')for n in inner_names):raise RangeUnsupported('Extracted ZIP contains no WebAssembly binary')
            record={'official_url':URL,'official_full_tpz_sha256_reference_only':OFFICIAL_TPZ_SHA256,'full_tpz_sha256_verified':False,'member':info.filename,'member_crc32':f'{info.CRC:08x}','member_zip_crc_verified':True,'member_sha256':hashlib.sha256(data).hexdigest(),'member_bytes':len(data),'tpz_total_bytes':remote.size,'downloaded_bytes':sum(r['received_bytes']for r in remote.requests),'requests':remote.requests,'elapsed_seconds':time.monotonic()-began,'template_contents':inner_names}
            (args.output_dir/'official-template-range-audit.json').write_text(json.dumps(record,indent=2)+'\n')
            print('OFFICIAL_WEB_TEMPLATE_EXTRACTED',target,'downloaded_bytes=',record['downloaded_bytes'],'instead_of=',remote.size,'sha256=',record['member_sha256'])
            return 0
    except (RangeUnsupported,zipfile.BadZipFile,OSError)as error:
        print('RANGE_EXTRACTION_UNAVAILABLE:',error,flush=True)
        print('No full TPZ download was attempted. The parent may choose the official full TPZ URL:',URL,flush=True)
        return 42

if __name__=='__main__':raise SystemExit(main())
