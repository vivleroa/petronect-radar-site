#!/usr/bin/env pwsh
<#
  Gera docs/index.html — landing de consultoria + dashboard ao vivo das licitacoes
  abertas da Petrobras (Petronect). Publicado via GitHub Pages (repo publico).
  Sem e-mail, sem segredos: apenas coleta o endpoint publico e monta a pagina.
#>
$ErrorActionPreference = 'Stop'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch {}
$root   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$docs   = Join-Path $root 'docs'
if (-not (Test-Path $docs)) { New-Item -ItemType Directory -Path $docs -Force | Out-Null }

$EMAIL = if ($env:EMAIL_CONTATO) { $env:EMAIL_CONTATO } else { 'vivleroa@gmail.com' }
$MARCA = if ($env:MARCA) { $env:MARCA } else { '@consultxlicitacoes' }

function Get-Setor($t) {
  switch -Regex ($t) {
    'po[çc]o|sondagem|obturador|revestimento|completa[çc]|workover|perfura|packer|submers|risers?|flowlines?|umbilical' { 'Sondagem/Poços'; break }
    'duto|flexíve|subsea|submarin|pipeline|oleoduto|gasoduto|manifold|árvore de natal' { 'Dutos/Subsea'; break }
    'manuten[çc]|permutador|v[áa]lvula|caldeiraria|jateamento|integridade|inspe[çc]|paradas?|turnaround|reparo' { 'Manutenção industrial'; break }
    'obra|constru[çc]|montagem|engenharia|reforma|edifica[çc]|terraplan|civil' { 'Engenharia/Obras'; break }
    'andaime|isolamento t[ée]rmico' { 'Andaimes/Isolamento'; break }
    'clarificante|químic|corros[ãa]o|inibidor|desemulsific|floculante|reagente|catalisador|solvente|amina|carbamida' { 'Químicos/Produtos'; break }
    'equipamento|material|motor|compressor|gerador|transformador|bomba|instrumenta[çc]|tubula|conex|flange|acess[óo]rio|filtro|ventilador' { 'Equipamentos/Materiais'; break }
    'software|licenciamento|sistema de informa|telecom|rede de dados|data center|nuvem|cloud|aplicativo|roteador|vpn' { 'TI/Software/Telecom'; break }
    'transporte|log[íi]stica|frota|ve[íi]culo|embarca[çc]|afretamento|navio|rebocador|guindaste|armazenagem|movimenta[çc]' { 'Logística/Transporte'; break }
    'publicidade|propaganda|consultoria|treinamento|recursos humanos|limpeza|vigil[âa]ncia|alimenta[çc]|facilities|apoio|financeiro' { 'Serviços adm./RH'; break }
    'ambient|resíduo|efluente|descomissi|inc[êe]ndio|hídric' { 'Meio ambiente/SMS'; break }
    'el[ée]tric|energia|subesta[çc]|fotovolta|e[óo]lic|atuador' { 'Energia/Elétrica'; break }
    default { 'Outros' }
  }
}

# ---------- coleta ----------
$ua  = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0 Safari/537.36'
$url = 'https://www.petronect.com.br/sap/opu/odata/SAP/YPCON_GET_XML_SRV/getXMLSet(''01'')?$format=json'
$resp = $null
for ($try = 1; $try -le 3; $try++) {
  try { $resp = Invoke-WebRequest -Uri $url -Headers @{ 'User-Agent'=$ua; 'Accept'='application/json' } -UseBasicParsing -TimeoutSec 120; break }
  catch { if ($try -eq 3) { throw }; Start-Sleep -Seconds (6*$try) }
}
$tab = (($resp.Content | ConvertFrom-Json).d.EvXml | ConvertFrom-Json).TAB
$hoje = (Get-Date).Date
$items = New-Object System.Collections.Generic.List[object]
foreach ($o in $tab) {
  if (-not $o.END_DATE -or $o.END_DATE -eq '0000-00-00') { continue }
  $fim = [datetime]::ParseExact($o.END_DATE, 'yyyy-MM-dd', $null)
  if ($fim -lt $hoje) { continue }
  $obj = if ($o.DESC_OBJ_CONTRAT) { $o.DESC_OBJ_CONTRAT } else { $o.OPPORT_DESCR }
  $obj = ([string]$obj -replace '\s+', ' ').Trim()
  $dias = [int][math]::Round(($fim - $hoje).TotalDays)
  $reg  = (@($o.REGIONS | ForEach-Object { $_.REGION }) | Where-Object { $_ } | Select-Object -Unique) -join ','
  $items.Add([pscustomobject]@{
    n=$o.OPPORT_NUM; o=$obj.Substring(0,[Math]::Min(150,$obj.Length)); s=(Get-Setor $obj)
    a= if ($o.NAT_COVERAGE -eq 'I') {'Int'} else {'Nac'}; r=$reg; f=$o.END_DATE; d=$dias
  })
}
$items = $items.ToArray()
$total = $items.Count
$fecha = @($items | Where-Object { $_.d -le 3 }).Count
$porSetor = $items | Group-Object s | Sort-Object Count -Descending
$nSetores = @($porSetor).Count
$cont = @($porSetor | ForEach-Object { @{ s=$_.Name; c=$_.Count } })
$data = @{ rows=$items; cont=$cont } | ConvertTo-Json -Depth 4 -Compress
$dataHoje = Get-Date -Format 'dd/MM/yyyy HH:mm'

# ---------- template ----------
$tpl = @'
<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Venda para a Petrobras — %%MARCA%%</title>
<style>
:root{--bg:#0B1F1A;--card:#0F2A23;--ink:#EAF2EE;--soft:#9DB3AA;--line:#1E3B32;--green:#2FBF9B;--green2:#12A183;--amber:#E8B33E;--paper:#F4F1EA;--pink:#B23A22;--warn:#9C6C12;--ok:#2E8B6F;}
*{box-sizing:border-box;margin:0;padding:0;}
body{background:var(--paper);color:#14231D;font-family:ui-sans-serif,system-ui,"Segoe UI",Roboto,Arial,sans-serif;-webkit-font-smoothing:antialiased;line-height:1.55;}
.mono{font-family:ui-monospace,Consolas,monospace;font-variant-numeric:tabular-nums;}
.hero{background:radial-gradient(120% 90% at 12% 8%,#0F2A23 0%,#0B1F1A 60%);color:var(--ink);padding:70px 24px 60px;}
.wrap{max-width:1080px;margin:0 auto;}
.eyebrow{font-size:12px;letter-spacing:.18em;text-transform:uppercase;color:var(--green);font-weight:700;display:flex;align-items:center;gap:10px;}
.eyebrow::before{content:"";width:26px;height:2px;background:var(--amber);}
h1{font-size:clamp(34px,6vw,60px);line-height:1.02;letter-spacing:-.03em;font-weight:800;margin:18px 0 16px;text-wrap:balance;}
h1 em{font-style:normal;color:var(--green);}
.lede{font-size:clamp(16px,2vw,19px);color:var(--soft);max-width:60ch;}
.kpis{display:flex;gap:14px;flex-wrap:wrap;margin:34px 0 30px;}
.kpi{background:var(--card);border:1px solid var(--line);border-radius:14px;padding:18px 22px;min-width:150px;}
.kpi .n{font-size:38px;font-weight:800;letter-spacing:-.02em;color:#fff;}
.kpi .n.a{color:var(--amber);}
.kpi .l{font-size:12.5px;color:var(--soft);margin-top:4px;}
.cta{display:inline-flex;align-items:center;gap:10px;background:var(--green);color:#04120E;font-weight:800;text-decoration:none;padding:15px 26px;border-radius:12px;font-size:16px;}
.cta:hover{background:var(--green2);}
.cta-sub{font-size:13px;color:var(--soft);margin-top:12px;}
.steps{display:grid;grid-template-columns:repeat(3,1fr);gap:14px;margin-top:44px;}
.stp{background:rgba(255,255,255,.04);border:1px solid var(--line);border-radius:12px;padding:18px;}
.stp .b{width:34px;height:34px;border-radius:9px;background:var(--green);color:#04120E;display:flex;align-items:center;justify-content:center;font-weight:800;margin-bottom:12px;}
.stp h3{font-size:16px;color:#fff;margin-bottom:6px;}
.stp p{font-size:13px;color:var(--soft);}
@media(max-width:720px){.steps{grid-template-columns:1fr;}}
.board{padding:52px 24px 30px;}
.board h2{font-size:clamp(22px,3vw,30px);font-weight:800;letter-spacing:-.01em;}
.board .sub{color:#5E6F67;font-size:14px;margin:6px 0 22px;}
.controls{display:flex;gap:12px;flex-wrap:wrap;margin-bottom:14px;align-items:center;}
.search{flex:1 1 260px;display:flex;align-items:center;gap:8px;background:#fff;border:1px solid #DDD7C9;border-radius:10px;padding:0 12px;}
.search input{border:0;outline:0;background:transparent;font-size:14px;padding:12px 0;width:100%;font-family:inherit;}
select{appearance:none;background:#fff;border:1px solid #DDD7C9;border-radius:10px;padding:11px 14px;font-size:13px;font-family:inherit;cursor:pointer;}
.chips{display:flex;gap:7px;flex-wrap:wrap;margin-bottom:16px;}
.chip{font-size:12.5px;font-weight:600;padding:6px 12px;border-radius:999px;border:1px solid #DDD7C9;background:#fff;color:#5E6F67;cursor:pointer;}
.chip.active{background:var(--green2);border-color:var(--green2);color:#fff;}
.chip .c{opacity:.7;font-size:11px;}
.status{font-size:13px;color:#5E6F67;margin:6px 2px 12px;}
.status b{color:#14231D;}
.tscroll{overflow-x:auto;border:1px solid #E4DECF;border-radius:12px;background:#fff;}
table{border-collapse:collapse;width:100%;min-width:720px;}
th{text-align:left;font-size:11px;text-transform:uppercase;letter-spacing:.05em;color:#8A9086;font-weight:700;padding:12px 14px;border-bottom:1px solid #E4DECF;}
td{padding:11px 14px;border-bottom:1px solid #EFEADD;font-size:13px;vertical-align:top;}
tr:last-child td{border-bottom:none;}
td.code{color:var(--green2);font-weight:700;white-space:nowrap;}
td.obj .meta{color:#8A9086;font-size:11px;margin-top:2px;}
.pill{display:inline-block;padding:3px 9px;border-radius:999px;font-size:11px;font-weight:700;white-space:nowrap;}
.pill.crit{color:#fff;background:var(--pink);}.pill.warn{color:#fff;background:var(--warn);}.pill.ok{color:#fff;background:var(--ok);}
footer{padding:26px 24px 50px;color:#8A9086;font-size:12.5px;text-align:center;}
footer a{color:var(--green2);}
</style></head><body>
<div class="hero"><div class="wrap">
  <div class="eyebrow">%%MARCA%% · Consultoria em licitações Petrobras</div>
  <h1>Sua empresa pode <em>vender para a Petrobras</em>. Só precisa entrar do jeito certo.</h1>
  <p class="lede">Existem oportunidades abertas agora mesmo — de bens e serviços que empresas médias fornecem todo dia. Eu ajudo você a se cadastrar na família certa, tirar o CRCC e não perder nenhum prazo.</p>
  <div class="kpis">
    <div class="kpi"><div class="n">%%TOTAL%%</div><div class="l">licitações abertas agora</div></div>
    <div class="kpi"><div class="n a">%%FECHA%%</div><div class="l">fecham em ≤ 3 dias</div></div>
    <div class="kpi"><div class="n">%%NSET%%</div><div class="l">setores com demanda</div></div>
  </div>
  <a class="cta" href="mailto:%%EMAIL%%?subject=Quero%20vender%20para%20a%20Petrobras&body=Ol%C3%A1!%20Vi%20o%20radar%20de%20licita%C3%A7%C3%B5es%20e%20quero%20saber%20como%20minha%20empresa%20pode%20participar.">Quero um diagnóstico gratuito →</a>
  <div class="cta-sub">Resposta rápida. Sem compromisso.</div>
  <div class="steps">
    <div class="stp"><div class="b">1</div><h3>Diagnóstico</h3><p>Descubro em quais famílias Petrobras sua empresa se encaixa.</p></div>
    <div class="stp"><div class="b">2</div><h3>Habilitação</h3><p>Conduzo o CRCC e a documentação que abre a porta.</p></div>
    <div class="stp"><div class="b">3</div><h3>Monitoramento</h3><p>Aviso todo dia as oportunidades do seu setor, com prazo.</p></div>
  </div>
</div></div>

<div class="board wrap">
  <h2>Oportunidades abertas agora</h2>
  <div class="sub">Dados ao vivo do Petronect · atualizado em %%DATAHOJE%%</div>
  <div class="controls">
    <label class="search"><svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#8A9086" stroke-width="2"><circle cx="11" cy="11" r="7"/><path d="m21 21-4.3-4.3"/></svg><input id="q" type="search" placeholder="Buscar por objeto ou número…"></label>
    <select id="sort"><option value="d-asc">Mais urgente</option><option value="d-desc">Mais folgado</option></select>
  </div>
  <div class="chips" id="chips"></div>
  <div class="status">Mostrando <b id="shown">0</b> de <b id="tot">0</b> oportunidades <span id="fl"></span></div>
  <div class="tscroll"><table><thead><tr><th>Número</th><th>Objeto</th><th>Encerra</th><th>Prazo</th></tr></thead><tbody id="body"></tbody></table></div>
</div>
<footer>Fonte: endpoint público do Petronect. As oportunidades são públicas; para participar é preciso Taxa de Acesso + CRCC. · <a href="mailto:%%EMAIL%%">%%EMAIL%%</a> · %%MARCA%%</footer>

<script>
const DB = %%DATA%%;
const st = { q:'', setor:'', sort:'d-asc' };
const esc = s => (s||'').replace(/[&<>"]/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]));
const fmt = f => { if(!f) return '—'; const p=f.split('-'); return p[2]+'/'+p[1]; };
const pill = d => { const l=d<=0?'hoje':d+(d===1?' dia':' dias'); const c=d<=2?'crit':d<=7?'warn':'ok'; return '<span class="pill '+c+'">'+l+'</span>'; };
const chips=document.getElementById('chips');
function buildChips(){ chips.innerHTML='';
  const all=document.createElement('button'); all.className='chip'+(st.setor===''?' active':''); all.innerHTML='Todos <span class="c">'+DB.rows.length+'</span>'; all.onclick=()=>{st.setor='';render();}; chips.appendChild(all);
  DB.cont.forEach(x=>{ const b=document.createElement('button'); b.className='chip'+(st.setor===x.s?' active':''); b.innerHTML=esc(x.s)+' <span class="c">'+x.c+'</span>'; b.onclick=()=>{st.setor=st.setor===x.s?'':x.s;render();}; chips.appendChild(b); });
}
function render(){ buildChips();
  const q=st.q.trim().toLowerCase();
  let r=DB.rows.filter(x=>{ if(st.setor&&x.s!==st.setor)return false; if(q&&!((x.o||'').toLowerCase().includes(q)||x.n.includes(q)))return false; return true; });
  const dir=st.sort.endsWith('asc')?1:-1; r.sort((a,b)=>(a.d-b.d)*dir);
  document.getElementById('body').innerHTML=r.map(x=>{
    const flag=x.a==='Int'?' · <b style="color:#B57F00">INT</b>':''; const reg=x.r?' · '+esc(x.r):'';
    return '<tr><td class="code mono">'+esc(x.n)+'</td><td class="obj">'+esc(x.o)+'<div class="meta">'+esc(x.s)+reg+flag+'</div></td><td class="mono">'+fmt(x.f)+'</td><td>'+pill(x.d)+'</td></tr>';
  }).join('');
  document.getElementById('shown').textContent=r.length; document.getElementById('tot').textContent=DB.rows.length;
  document.getElementById('fl').textContent=st.setor?'· '+st.setor:'';
}
document.getElementById('q').addEventListener('input',e=>{st.q=e.target.value;render();});
document.getElementById('sort').addEventListener('change',e=>{st.sort=e.target.value;render();});
render();
</script></body></html>
'@

$html = $tpl.Replace('%%DATA%%', $data).Replace('%%TOTAL%%', [string]$total).Replace('%%FECHA%%', [string]$fecha).Replace('%%NSET%%', [string]$nSetores).Replace('%%DATAHOJE%%', $dataHoje).Replace('%%EMAIL%%', $EMAIL).Replace('%%MARCA%%', $MARCA)
[System.IO.File]::WriteAllText((Join-Path $docs 'index.html'), $html, (New-Object System.Text.UTF8Encoding($false)))
Write-Host ("Dashboard gerado: $total abertas, $fecha fecham <=3d. -> docs/index.html")
