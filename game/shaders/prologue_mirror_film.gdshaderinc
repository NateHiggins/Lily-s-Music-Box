// Local authored withdrawal; negative cover preserves ordinary moisture exactly.
uniform vec2 prologue_film = vec2(-1.0, 0.0);
float story_branch(vec2 p, vec2 a, vec2 b, float growth) {
 vec2 end=mix(a,b,clamp(growth,0.0,1.0));
 vec2 ab=end-a;
 float t=clamp(dot(p-a,ab)/max(dot(ab,ab),0.000001),0.0,1.0);
 return length(p-a-ab*t);
}
float prologue_mirror_wet(vec2 uv,float natural_wet) {
 if(prologue_film.x<0.0)return natural_wet;
 float progress=clamp(prologue_film.y,0.0,1.0);
 float wet=max(natural_wet,prologue_film.x);
 float aa=max(length(fwidth(uv)),.0015);
 float growth=progress*1.75;
 float distance_to_stem=story_branch(uv,vec2(.44,-.05),vec2(.52,.28),growth*3.0);
 if(growth>.30)distance_to_stem=min(distance_to_stem,story_branch(uv,vec2(.52,.28),vec2(.47,.60),(growth-.30)*2.0));
 if(growth>.65)distance_to_stem=min(distance_to_stem,story_branch(uv,vec2(.47,.60),vec2(.56,1.05),(growth-.65)*2.0));
 float width=.004+progress*.016;
 float clear=(1.0-smoothstep(width-aa,width+aa,distance_to_stem))*smoothstep(.03,.09,progress);
 for(int i=0;i<8;i++) {
  float row=float(i);
  float side=i%2==0 ? -1.0 : 1.0;
  vec2 a=vec2(.50+sin(row*3.7)*.025,.14+row*.105);
  vec2 b=a+vec2(side*(.22+fract(row*.618)*.13),.10+fract(row*.37)*.13);
  float advance=clamp((progress-.12-row*.065)*3.5,0.0,1.0);
  float distance_to_branch=story_branch(uv,a,b,advance);
  float branch_width=.002+progress*.009;
  float opened=1.0-smoothstep(branch_width-aa,branch_width+aa,distance_to_branch);
  clear=max(clear,opened*smoothstep(0.0,.08,advance));
 }
 // The broad veil thins last; paths remain fine instead of swelling into blobs.
 clear=mix(clear,1.0,smoothstep(.66,1.0,progress));
 return wet*(1.0-progress*.12)*(1.0-clear);
}
