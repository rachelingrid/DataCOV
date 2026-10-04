// estat.js - estatistica usada pelo site de comparacao (roda no navegador,
// sem bibliotecas). Mesmo metodo de octave/glm_poisson.m e compara_faixas.m:
// regressao de Poisson com offset log(exposicao), quasi-Poisson (phi >= 1),
// p-valores pela t de Student, ajuste de Holm.
(function (raiz) {
  'use strict';

  // resolve A x = b (eliminacao de Gauss com pivoteamento parcial)
  function resolve(A, b) {
    const n = b.length, M = A.map((l, i) => l.concat([b[i]]));
    for (let c = 0; c < n; c++) {
      let p = c;
      for (let r = c + 1; r < n; r++) if (Math.abs(M[r][c]) > Math.abs(M[p][c])) p = r;
      if (Math.abs(M[p][c]) < 1e-300) return null;
      [M[c], M[p]] = [M[p], M[c]];
      for (let r = 0; r < n; r++) {
        if (r === c) continue;
        const f = M[r][c] / M[c][c];
        for (let k = c; k <= n; k++) M[r][k] -= f * M[c][k];
      }
    }
    return M.map((l, i) => l[n] / l[i]);
  }
  function inversa(A) {
    const n = A.length, I = [];
    for (let j = 0; j < n; j++) {
      const e = new Array(n).fill(0); e[j] = 1;
      const x = resolve(A, e); if (!x) return null;
      I.push(x);
    }
    return A.map((_, i) => I.map(col => col[i]));
  }

  // GLM Poisson por IRLS. X: n linhas de p colunas; y contagens; off = log(exposicao)
  function glmPoisson(X, y, off) {
    const n = y.length, p = X[0].length;
    const res = { ok: false, b: null, V: null, phi: NaN, df: n - p };
    if (n <= p || y.reduce((a, v) => a + v, 0) === 0 || off.some(v => !isFinite(v))) return res;
    let mu = y.map(v => v + 0.5), eta = mu.map(Math.log), b = new Array(p).fill(0);
    for (let it = 0; it < 100; it++) {
      const z = y.map((v, i) => eta[i] - off[i] + (v - mu[i]) / mu[i]);
      const XtWX = [], XtWz = [];
      for (let a = 0; a < p; a++) {
        XtWX.push(new Array(p).fill(0)); XtWz.push(0);
        for (let i = 0; i < n; i++) {
          XtWz[a] += X[i][a] * mu[i] * z[i];
          for (let c = 0; c < p; c++) XtWX[a][c] += X[i][a] * mu[i] * X[i][c];
        }
      }
      const bn = resolve(XtWX, XtWz); if (!bn) return res;
      eta = X.map((l, i) => l.reduce((s, v, k) => s + v * bn[k], 0) + off[i]);
      mu = eta.map(Math.exp);
      const dif = Math.max(...bn.map((v, k) => Math.abs(v - b[k])));
      b = bn;
      if (dif < 1e-10) break;
    }
    const I = [];
    for (let a = 0; a < p; a++) {
      I.push(new Array(p).fill(0));
      for (let i = 0; i < n; i++) for (let c = 0; c < p; c++) I[a][c] += X[i][a] * mu[i] * X[i][c];
    }
    const Iinv = inversa(I); if (!Iinv) return res;
    const pearson = y.reduce((s, v, i) => s + (v - mu[i]) ** 2 / mu[i], 0);
    res.phi = Math.max(1, pearson / res.df);
    res.V = Iinv.map(l => l.map(v => v * res.phi));
    res.b = b; res.ok = b.every(isFinite);
    return res;
  }

  // funcao beta incompleta regularizada (Numerical Recipes, fracao continua)
  function lgamma(x) {
    const c = [76.18009172947146, -86.50532032941677, 24.01409824083091,
      -1.231739572450155, 0.1208650973866179e-2, -0.5395239384953e-5];
    let y = x, t = x + 5.5; t -= (x + 0.5) * Math.log(t);
    let s = 1.000000000190015;
    for (let j = 0; j < 6; j++) s += c[j] / ++y;
    return -t + Math.log(2.5066282746310005 * s / x);
  }
  function betacf(a, b, x) {
    const MAXIT = 300, EPS = 3e-16, FPMIN = 1e-300;
    let qab = a + b, qap = a + 1, qam = a - 1, c = 1, d = 1 - qab * x / qap;
    if (Math.abs(d) < FPMIN) d = FPMIN;
    d = 1 / d; let h = d;
    for (let m = 1; m <= MAXIT; m++) {
      const m2 = 2 * m;
      let aa = m * (b - m) * x / ((qam + m2) * (a + m2));
      d = 1 + aa * d; if (Math.abs(d) < FPMIN) d = FPMIN;
      c = 1 + aa / c; if (Math.abs(c) < FPMIN) c = FPMIN;
      d = 1 / d; h *= d * c;
      aa = -(a + m) * (qab + m) * x / ((a + m2) * (qap + m2));
      d = 1 + aa * d; if (Math.abs(d) < FPMIN) d = FPMIN;
      c = 1 + aa / c; if (Math.abs(c) < FPMIN) c = FPMIN;
      d = 1 / d; const del = d * c; h *= del;
      if (Math.abs(del - 1) < EPS) break;
    }
    return h;
  }
  function betainc(x, a, b) {
    if (x <= 0) return 0; if (x >= 1) return 1;
    const bt = Math.exp(lgamma(a + b) - lgamma(a) - lgamma(b) + a * Math.log(x) + b * Math.log(1 - x));
    return x < (a + 1) / (a + b + 2) ? bt * betacf(a, b, x) / a : 1 - bt * betacf(b, a, 1 - x) / b;
  }
  const tPvalor = (t, df) => betainc(df / (df + t * t), df / 2, 0.5);    // bicaudal
  function tQuantil(pr, df) {                                              // pr em (0.5,1)
    let lo = 0, hi = 1e4;
    for (let i = 0; i < 200; i++) {
      const m = (lo + hi) / 2;
      (1 - 0.5 * betainc(df / (df + m * m), df / 2, 0.5)) < pr ? lo = m : hi = m;
    }
    return (lo + hi) / 2;
  }
  function holm(p) {
    const idx = p.map((v, i) => [v, i]).filter(([v]) => v != null && !isNaN(v)).sort((a, b) => a[0] - b[0]);
    const m = idx.length, out = p.map(() => null);
    let acc = 0;
    idx.forEach(([v, i], k) => { acc = Math.max(acc, Math.min(1, (m - k) * v)); out[i] = acc; });
    return out;
  }

  // Janela da comparacao (mesma regra de octave/janela_simetrica.m):
  // k anos completos depois de 2020 x os k anos imediatamente anteriores.
  function janela(anosOk, pre, pos, simetrico) {
    let a = anosOk.filter(x => pre.includes(x)).sort((p, q) => p - q);
    let d = anosOk.filter(x => pos.includes(x)).sort((p, q) => p - q);
    if (simetrico) { const k = Math.min(a.length, d.length); a = a.slice(a.length - k); d = d.slice(0, k); }
    return { pre: a, pos: d };
  }

  // Testes de um estrato. anos, y, expo (populacao x meses/12) ja filtrados
  // (sem 2020 e sem anos incompletos). pre/pos: listas de anos. t0 = ano da pandemia.
  // Comparacao depois x antes: so a janela (simetrica se simetrico=true).
  // Serie interrompida: todos os anos recebidos.
  function testa(anos, y, expo, pre, pos, t0, alfa, minAnos, simetrico) {
    alfa = alfa || 0.05; minAnos = minAnos || 3;
    const J = janela(anos, pre, pos, simetrico !== false);
    const ePre = anos.map(a => J.pre.includes(a)), ePos = anos.map(a => J.pos.includes(a));
    const R = {
      ok: false, npre: ePre.filter(Boolean).length, npos: ePos.filter(Boolean).length,
      cpre: y.filter((_, i) => ePre[i]).reduce((s, v) => s + v, 0),
      cpos: y.filter((_, i) => ePos[i]).reduce((s, v) => s + v, 0),
      janelaPre: J.pre, janelaPos: J.pos
    };
    const xpre = expo.filter((_, i) => ePre[i]).reduce((s, v) => s + v, 0);
    const xpos = expo.filter((_, i) => ePos[i]).reduce((s, v) => s + v, 0);
    R.taxaPre = xpre > 0 ? R.cpre / xpre * 1e6 : null;
    R.taxaPos = xpos > 0 ? R.cpos / xpos * 1e6 : null;
    R.mediaPre = R.npre ? R.cpre / R.npre : null;
    R.mediaPos = R.npos ? R.cpos / R.npos : null;
    if (R.npre < minAnos || R.npos < minAnos || R.cpre === 0) return R;
    const off = expo.map(Math.log), d = anos.map(a => pos.includes(a) ? 1 : 0);
    const w = anos.map((_, i) => ePre[i] || ePos[i]);
    const sel = (arr) => arr.filter((_, i) => w[i]);
    const A = glmPoisson(sel(anos.map((_, i) => [1, d[i]])), sel(y), sel(off));
    if (!A.ok) return R;
    let se = Math.sqrt(A.V[1][1]), q = tQuantil(1 - alfa / 2, A.df);
    Object.assign(R, {
      ok: true, phi: A.phi, rr: Math.exp(A.b[1]), rrInf: Math.exp(A.b[1] - q * se),
      rrSup: Math.exp(A.b[1] + q * se), p: tPvalor(A.b[1] / se, A.df), df: A.df
    });
    // serie interrompida: log taxa = b0 + b1 t + b2 pos + b3 pos t ; salto em t=1
    const t = anos.map(a => a - t0);
    const B = glmPoisson(anos.map((_, i) => [1, t[i], d[i], d[i] * t[i]]), y, off);
    if (B.ok && B.df >= 1) {
      q = tQuantil(1 - alfa / 2, B.df);
      const s1 = Math.sqrt(B.V[1][1]);
      R.tend = 100 * (Math.exp(B.b[1]) - 1);
      R.tendInf = 100 * (Math.exp(B.b[1] - q * s1) - 1);
      R.tendSup = 100 * (Math.exp(B.b[1] + q * s1) - 1);
      const est = B.b[2] + B.b[3], s = Math.sqrt(B.V[2][2] + B.V[3][3] + 2 * B.V[2][3]);
      R.salto = Math.exp(est); R.saltoInf = Math.exp(est - q * s); R.saltoSup = Math.exp(est + q * s);
      R.pSalto = tPvalor(est / s, B.df);
    }
    return R;
  }

  raiz.Estat = { glmPoisson, tPvalor, tQuantil, holm, testa, janela, betainc };
})(typeof window !== 'undefined' ? window : globalThis);
