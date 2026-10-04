'use strict';
// Node >=22.15. Recompress Blender's seekable Zstd frames without changing
// any decoded native byte. Standard frame table: https://github.com/facebook/zstd/blob/dev/contrib/seekable_format/zstd_seekable_compression_format.md
const fs=require('node:fs'),path=require('node:path'),z=require('node:zlib'),crypto=require('node:crypto');
const [source,target,report]=process.argv.slice(2).map(p=>path.resolve(p));
if(!source||!target||!report||source===target)throw Error('Three distinct file paths required');
const input=fs.readFileSync(source);const count=input.readUInt32LE(input.length-9);const descriptor=input[input.length-5];
if(descriptor!==0||input.readUInt32LE(input.length-4)!==0x8F92EAB1)throw Error('Unsupported seek table');
const tableStart=input.length-(count*8+17);if(input.readUInt32LE(tableStart)!==0x184D2A5E||input.readUInt32LE(tableStart+4)!==count*8+9)throw Error('Bad seek table size');
const before=crypto.createHash('sha256'),after=crypto.createHash('sha256');const rows=[];let at=0,decodedBytes=0,packedBytes=0;
const fd=fs.openSync(target,'wx');
try{
 for(let i=0;i<count;i++){
  const length=input.readUInt32LE(tableStart+8+i*8),expected=input.readUInt32LE(tableStart+12+i*8);
  const decoded=z.zstdDecompressSync(input.subarray(at,at+length));if(decoded.length!==expected)throw Error('Frame size mismatch '+i);
  before.update(decoded);decodedBytes+=decoded.length;
  const packed=z.zstdCompressSync(decoded,{params:{[z.constants.ZSTD_c_compressionLevel]:19}});
  const checked=z.zstdDecompressSync(packed);if(!checked.equals(decoded))throw Error('Decoded frame changed '+i);
  after.update(checked);fs.writeSync(fd,packed);rows.push([packed.length,decoded.length]);packedBytes+=packed.length;at+=length;
  if(i%50===0)console.log('PACKED FRAMES',i+1,'/',count,'bytes',packedBytes);
 }
 if(at!==tableStart)throw Error('Unaccounted source bytes');
 const footer=Buffer.alloc(count*8+17);footer.writeUInt32LE(0x184D2A5E);footer.writeUInt32LE(count*8+9,4);
 rows.forEach(([c,d],i)=>{footer.writeUInt32LE(c,8+i*8);footer.writeUInt32LE(d,12+i*8);});
 footer.writeUInt32LE(count,footer.length-9);footer[footer.length-5]=0;footer.writeUInt32LE(0x8F92EAB1,footer.length-4);fs.writeSync(fd,footer);
}finally{fs.closeSync(fd);}
const original=before.digest('hex');if(after.digest('hex')!==original)throw Error('Full decoded payload changed');
const result={evidence_class:'INERT',source,target,zstd_level:19,frames:count,decoded_bytes:decodedBytes,decoded_sha256:original,decoded_bytes_identical:true,source_bytes:input.length,target_bytes:fs.statSync(target).size};
fs.writeFileSync(report,JSON.stringify(result,null,2)+'\n');console.log(JSON.stringify(result));
