import { site, copy } from './content.js';
const theme=site.themes[document.body.dataset.theme];
if(theme){for(const key of ['deep','forest','cream','gold'])document.documentElement.style.setProperty('--'+key,theme[key]);document.documentElement.style.setProperty('--world-art',`url("${theme.artwork}")`);}
let language;
try { language = localStorage.getItem('jason-language'); } catch {}
if (!['zh','en'].includes(language)) language = navigator.language.toLowerCase().startsWith('zh') ? 'zh' : 'en';
export const t = key => copy[language][key] ?? key;
export const currentLanguage = () => language;

function renderContacts() {
  const root = document.getElementById('extra-contacts');
  if (!root) return;
  root.replaceChildren();
  for (const [kind,value] of Object.entries(site.contacts)) {
    if (typeof value !== 'string' || !value.trim()) continue;
    const row = document.createElement('div'); row.className='contact-row';
    if (kind === 'wechat') {
      if (/^https:\/\//i.test(value)) {
        const link=document.createElement('a');link.href=value;link.target='_blank';link.rel='noopener noreferrer';link.textContent=t('wechatLabel')+' ↗';row.append(link);root.append(row);continue;
      }
      const label=document.createElement('span');label.textContent=`${t('wechatLabel')}: ${value}`;row.append(label);
      if (navigator.clipboard) {const button=document.createElement('button');button.type='button';button.textContent=t('copyContact');button.addEventListener('click',async()=>{try{await navigator.clipboard.writeText(value);button.textContent=t('copied');}catch{button.remove();}});row.append(button);}
    } else {
      const link=document.createElement('a');
      if(kind==='gmail') link.href=`mailto:${value}`;
      else if(kind==='phone') link.href=`tel:${value.replace(/[^+\d]/g,'')}`;
      else {try {const url=new URL(value);if(url.protocol!=='https:')continue;link.href=url.href;}catch{continue;}link.target='_blank';link.rel='noopener noreferrer';}
      link.textContent=`${t(kind+'Label')}: ${value}`;row.append(link);
    }
    root.append(row);
  }
}

function applyLanguage() {
  document.documentElement.lang = language === 'zh' ? 'zh-CN' : 'en';
  for (const el of document.querySelectorAll('[data-i18n]')) el.textContent=t(el.dataset.i18n);
  for (const button of document.querySelectorAll('[data-language]')) button.setAttribute('aria-pressed',String(button.dataset.language===language));
  document.title=document.body.classList.contains('game-page')?'Forest Wanderer · Jason':t('pageTitle');
  const description=document.querySelector('meta[name="description"]');if(description)description.content=document.body.classList.contains('game-page')?site.games[0].description[language]:t('pageDescription');
  for (const el of document.querySelectorAll('[data-game-description]')) el.textContent=site.games[0].description[language];
  for (const el of document.querySelectorAll('[data-game-version]')) el.textContent=site.games[0].version;
  renderContacts();
  document.dispatchEvent(new CustomEvent('site-language-change'));
}
for(const button of document.querySelectorAll('[data-language]'))button.addEventListener('click',()=>{language=button.dataset.language;try{localStorage.setItem('jason-language',language);}catch{}applyLanguage();});

// Each new world supplies its own route and theme; the first card is also a
// useful HTML fallback. Extend the registry without cloning layout code.
const worlds=document.getElementById('worlds');
if(worlds){
  const template=worlds.firstElementChild;
  for(const [index,game] of site.games.entries()){
    const card=index===0?template:template.cloneNode(true);card.dataset.theme=game.theme;
    card.querySelector('.world-index').textContent=`${String(index+1).padStart(2,'0')} / ${game.title.toUpperCase()}`;
    card.querySelector('h3').textContent=game.title;
    const img=card.querySelector('img');img.src=game.screenshot;img.alt=`${game.title} — gameplay`;
    card.querySelectorAll('[data-transition]').forEach(a=>a.href=game.route);
    card.querySelector('.repo-link').href=game.repository;
    card.querySelector('[data-game-description]').removeAttribute('data-game-description');
    card.querySelector('.genre').removeAttribute('data-i18n');
    const setDescription=()=>{card.querySelector('.world-description').textContent=game.description[language];card.querySelector('.genre').textContent=game.genre[language];};
    document.addEventListener('site-language-change',setDescription);setDescription();
    if(index>0)worlds.append(card);
  }
}
applyLanguage();

document.addEventListener('click',event=>{
  const a=event.target.closest('a[data-transition]');
  if(!a||event.button!==0||event.ctrlKey||event.metaKey||event.shiftKey||event.altKey||a.target==='_blank')return;
  if(new URL(a.href).origin!==location.origin)return;
  if(matchMedia('(prefers-reduced-motion: reduce)').matches)return;
  event.preventDefault();
  if(document.documentElement.classList.contains('leaving'))return;
  document.documentElement.classList.add('leaving');
  setTimeout(()=>location.assign(a.href),350);
});
window.addEventListener('pageshow',()=>document.documentElement.classList.remove('leaving'));
