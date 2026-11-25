(() => {
  const page = https(location.href) || https(document.baseURI);
  const host = page?.hostname || '';
  const matches = (value, domain) => value === domain || value.endsWith('.' + domain);
  const reddit = matches(host, 'reddit.com');
  const twitter = matches(host, 'x.com') || matches(host, 'twitter.com');
  const pinterest = /(^|\.)pinterest\./.test(host);
  const profile = reddit ? 'reddit' : twitter ? 'x' : pinterest ? 'pinterest' : 'web';

  function https(value) {
    if (!value) return null;
    try {
      const url = new URL(value, document.baseURI);
      return url.protocol === 'https:' && !url.username && !url.password ? url : null;
    } catch (_) {
      return null;
    }
  }

  function fileKind(url) {
    const path = url.pathname.toLowerCase();
    if (/\.gif$/.test(path)) return 'gif';
    if (/\.(mp4|webm|m4v|mov)$/.test(path)) return 'video';
    if (/\.(jpe?g|png|webp|bmp|avif)$/.test(path)) return 'image';
    return null;
  }

  function inViewport(node, minSize) {
    const rect = node.getBoundingClientRect();
    if (rect.width < minSize || rect.height < minSize) return false;
    const style = getComputedStyle(node);
    const left = Math.max(0, rect.left);
    const right = Math.min(innerWidth, rect.right);
    const top = Math.max(0, rect.top);
    const bottom = Math.min(innerHeight, rect.bottom);
    if (style.visibility !== 'visible' || style.opacity === '0' ||
        style.filter.includes('blur(') || left >= right || top >= bottom) return false;

    const root = node.getRootNode();
    return [0.25, 0.75].some(fraction => {
      const x = left + (right - left) * fraction;
      const y = (top + bottom) / 2;
      let hit = document.elementFromPoint(x, y);
      if (hit && hit === root.host) hit = root.elementFromPoint(x, y);
      return hit === node || node.contains(hit) || (style.pointerEvents === 'none' && hit === node.parentElement);
    });
  }

  function imageSource(node) {
    const candidates = (node.getAttribute('srcset') || '').split(',')
      .map(value => value.trim().split(/\s+/))
      .filter(parts => parts.length && https(parts[0]))
      .sort((a, b) => (parseFloat(b[1]) || 0) - (parseFloat(a[1]) || 0));
    return https(candidates[0]?.[0]) || https(node.currentSrc) ||
      https(node.getAttribute('data-src')) || https(node.getAttribute('src'));
  }

  const items = new Map();
  const roots = [document];
  for (let i = 0; i < roots.length && roots.length < 50; i++) {
    for (const element of roots[i].querySelectorAll('*')) {
      if (roots.length >= 50) break;
      if (element.shadowRoot) roots.push(element.shadowRoot);
    }
  }
  const imageStyles = '[style*="background-image"]';
  const mediaSelector = 'img, video, a[href], ' +
    ['[data-testid="tweetPhoto"]', 'figure', '[role="img"]'].map(
      base => base + imageStyles + ', ' + base + ' ' + imageStyles
    ).join(', ');
  const nodes = roots.flatMap(root => Array.from(root.querySelectorAll(mediaSelector)));
  for (const node of nodes) {
    if (items.size >= 60) break;
    const tag = node.tagName;
    const postSelector = 'shreddit-post, article, [data-testid="post-container"], [data-test-id="pin"]';
    const card = node.closest(postSelector) || node.getRootNode().host?.closest(postSelector);
    const enclosingLink = node.closest('a[href]');
    let url, kind, thumbnail;

    if (tag === 'IMG' || (tag !== 'VIDEO' && tag !== 'A')) {
      if (node.closest('header, nav, footer, [role="banner"], [role="navigation"]')) continue;
      if (!inViewport(node, 75)) continue;
      if (tag === 'IMG') {
        url = imageSource(node);
      } else {
        const background = getComputedStyle(node).backgroundImage.match(/url\(["']?(.+?)["']?\)/);
        url = https(background?.[1]);
      }
      if (!url) continue;
      if (twitter && !(url.hostname === 'pbs.twimg.com' && url.pathname.startsWith('/media/'))) continue;
      if (pinterest && !matches(url.hostname, 'pinimg.com')) continue;
      if (reddit && !card && !['i.redd.it', 'preview.redd.it', 'external-preview.redd.it'].includes(url.hostname)) continue;
      if (/avatar|profile_images|emoji|sprite|favicon|logo/i.test(url.pathname)) continue;
      kind = fileKind(url) || (url.searchParams.get('format') === 'gif' ? 'gif' : 'image');
    } else if (tag === 'VIDEO') {
      if (!inViewport(node, 75)) continue;
      url = https(node.currentSrc) || https(node.getAttribute('src')) ||
        https(node.querySelector('source[src]')?.getAttribute('src'));
      if (!url || /\.(m3u8|mpd)$/i.test(url.pathname)) continue;
      kind = 'video';
      thumbnail = https(node.getAttribute('poster'));
    } else {
      if (!inViewport(node, 1) || node.querySelector('img, video')) continue;
      url = https(node.getAttribute('href'));
      kind = url && fileKind(url);
      if (!kind) continue;
    }

    if (!url || !kind) continue;
    url.hash = '';
    const link = https(card?.getAttribute('permalink')) ||
      https(card?.querySelector('a[href*="/status/"], a[href*="/comments/"], a[href*="/pin/"]')?.href) ||
      (tag !== 'A' && enclosingLink?.hostname === host ? https(enclosingLink.href) : null) || page;
    const title = card?.getAttribute('post-title') ||
      node.getAttribute('alt') || node.getAttribute('title') ||
      (tag === 'A' ? node.textContent.trim() : '') || document.title;
    const key = url.href;
    items.set(key, {
      url: key, kind, title: (title || '').trim().slice(0, 180),
      post: link?.href, thumbnail: thumbnail?.href,
      adult: ['nsfw', 'over-18'].some(name => {
        const flag = card?.getAttribute(name);
        return flag != null && flag.toLowerCase() !== 'false' && flag !== '0';
      }),
    });
  }
  return JSON.stringify({page: page?.href, profile, items: [...items.values()]});
})()
