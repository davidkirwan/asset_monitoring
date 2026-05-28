(function () {
  const TROY_OZ_TO_KG = 0.0311034768;
  const SATOSHIS_PER_BTC = 100000000;
  const FIATS = ['EUR', 'USD', 'GBP', 'JPY'];

  const ASSETS = [
    {
      id: 'gold',
      label: 'Gold',
      priced: true,
      type: 'metal',
      units: [
        { id: 'troy_oz', label: 'troy oz' },
        { id: 'grams', label: 'grams' }
      ],
      defaultUnit: 'troy_oz'
    },
    {
      id: 'silver',
      label: 'Silver',
      priced: true,
      type: 'metal',
      units: [
        { id: 'troy_oz', label: 'troy oz' },
        { id: 'grams', label: 'grams' }
      ],
      defaultUnit: 'troy_oz'
    },
    {
      id: 'bitcoin',
      label: 'Bitcoin',
      priced: true,
      type: 'crypto',
      units: [
        { id: 'btc', label: 'BTC' },
        { id: 'satoshis', label: 'satoshis' }
      ],
      defaultUnit: 'btc'
    },
    {
      id: 'ethereum',
      label: 'Ethereum',
      priced: true,
      type: 'crypto',
      units: [{ id: 'eth', label: 'ETH' }],
      defaultUnit: 'eth'
    },
    {
      id: 'stocks',
      label: 'Stocks',
      priced: false,
      type: 'fiat',
      units: FIATS.map(function (f) { return { id: f.toLowerCase(), label: f }; }),
      defaultUnit: 'eur'
    },
    {
      id: 'cash',
      label: 'Cash',
      priced: false,
      type: 'fiat',
      units: FIATS.map(function (f) { return { id: f.toLowerCase(), label: f }; }),
      defaultUnit: 'eur'
    },
    {
      id: 'property',
      label: 'Property',
      priced: false,
      type: 'fiat',
      units: FIATS.map(function (f) { return { id: f.toLowerCase(), label: f }; }),
      defaultUnit: 'eur'
    }
  ];

  const grid = document.getElementById('portfolio-grid');
  const statusEl = document.getElementById('portfolio-status');
  const saveStatusEl = document.getElementById('portfolio-save-status');
  const saveButton = document.getElementById('portfolio-save');
  const totalsEl = document.getElementById('portfolio-totals');
  const summaryCurrencyEl = document.getElementById('summary-currency');
  const historyStatusEl = document.getElementById('portfolio-history-status');
  const historyRangeEl = document.getElementById('portfolio-history-range');
  const chartsHost = document.getElementById('portfolio-charts');
  let spotData = { prices: {}, units: {} };
  let portfolio = defaultPortfolio();
  let portfolioHistory = null;
  let historyRange = 'day';
  let chartInstances = [];
  let dirty = false;
  let persisted = false;

  const SECONDS_PER_DAY = 86400;
  const CURRENCY_COLORS = {
    EUR: '#58a6ff',
    USD: '#3fb950',
    GBP: '#d2a106',
    JPY: '#f85149'
  };

  function defaultPortfolio() {
    return {
      summaryCurrency: 'EUR',
      holdings: ASSETS.reduce(function (acc, asset) {
        acc[asset.id] = { amount: '', unit: asset.defaultUnit };
        return acc;
      }, {})
    };
  }

  function applyPortfolioData(data) {
    const base = defaultPortfolio();
    base.summaryCurrency = data.summary_currency || data.summaryCurrency || base.summaryCurrency;
    ASSETS.forEach(function (asset) {
      const source = (data.holdings || {})[asset.id];
      if (source) {
        base.holdings[asset.id] = {
          amount: source.amount == null ? '' : String(source.amount),
          unit: source.unit || asset.defaultUnit
        };
      }
    });
    portfolio = base;
    persisted = !!data.persisted;
    summaryCurrencyEl.value = portfolio.summaryCurrency;
  }

  function setDirty(isDirty) {
    dirty = isDirty;
    if (saveStatusEl) {
      if (!persisted && !dirty) {
        saveStatusEl.textContent = 'Not saved to server yet';
      } else if (dirty) {
        saveStatusEl.textContent = 'Unsaved changes';
      } else {
        saveStatusEl.textContent = 'Saved';
      }
    }
  }

  function parseAmount(value) {
    const n = Number(String(value).replace(/,/g, '').trim());
    return Number.isFinite(n) ? n : 0;
  }

  function formatMoney(value, currency) {
    if (value == null) return '—';
    try {
      return new Intl.NumberFormat(undefined, {
        style: 'currency',
        currency: currency,
        maximumFractionDigits: currency === 'JPY' ? 0 : 2
      }).format(value);
    } catch (_e) {
      return value.toFixed(2) + ' ' + currency;
    }
  }

  function metalToKg(amount, unit) {
    if (unit === 'troy_oz') return amount * TROY_OZ_TO_KG;
    if (unit === 'grams') return amount / 1000;
    return 0;
  }

  function cryptoToCoins(amount, unit, assetId) {
    if (assetId === 'bitcoin') {
      if (unit === 'btc') return amount;
      if (unit === 'satoshis') return amount / SATOSHIS_PER_BTC;
    }
    if (assetId === 'ethereum' && unit === 'eth') return amount;
    return 0;
  }

  function fxReferenceQuotes() {
    if (spotData.fx_quotes) return spotData.fx_quotes;

    const gold = spotData.prices && spotData.prices.gold;
    if (gold && Object.keys(gold).length >= 2) return gold;

    const silver = spotData.prices && spotData.prices.silver;
    if (silver && Object.keys(silver).length >= 2) return silver;

    return null;
  }

  function convertFiat(amount, from, to, quotes) {
    from = from.toLowerCase();
    to = to.toLowerCase();
    if (from === to) return amount;
    if (!quotes || !quotes[from] || !quotes[to]) return null;

    const base = Number(quotes[from]);
    const target = Number(quotes[to]);
    if (!base || !target) return null;

    return amount * (target / base);
  }

  function estimateValue(asset, holding, currency) {
    const amount = parseAmount(holding.amount);
    if (amount <= 0) return null;

    const fiat = currency.toLowerCase();
    const prices = spotData.prices[asset.id] || {};

    if (asset.type === 'metal') {
      const price = prices[fiat];
      if (price == null) return null;
      return metalToKg(amount, holding.unit) * price;
    }

    if (asset.type === 'crypto') {
      const price = prices[fiat];
      if (price == null) return null;
      return cryptoToCoins(amount, holding.unit, asset.id) * price;
    }

    if (asset.type === 'fiat') {
      const quotes = fxReferenceQuotes();
      if (quotes) {
        const converted = convertFiat(amount, holding.unit, fiat, quotes);
        if (converted != null) return converted;
      }
      if (holding.unit === fiat) return amount;
    }

    return null;
  }

  function syncFormToPortfolio() {
    ASSETS.forEach(function (asset) {
      const row = grid.querySelector('[data-asset-id="' + asset.id + '"]');
      if (!row) return;
      portfolio.holdings[asset.id] = {
        amount: row.querySelector('[data-field="amount"]').value,
        unit: row.querySelector('[data-field="unit"]').value
      };
    });
    portfolio.summaryCurrency = summaryCurrencyEl.value;
  }

  function buildRow(asset) {
    const row = document.createElement('div');
    row.className = 'card portfolio-row';
    row.dataset.assetId = asset.id;

    const label = document.createElement('div');
    label.className = 'asset-label';
    label.textContent = asset.label;
    row.appendChild(label);

    const amountWrap = document.createElement('label');
    amountWrap.innerHTML = 'Amount<input type="text" inputmode="decimal" data-field="amount" aria-label="' + asset.label + ' amount" />';
    row.appendChild(amountWrap);

    const unitWrap = document.createElement('label');
    unitWrap.innerHTML = 'Unit<select data-field="unit" aria-label="' + asset.label + ' unit"></select>';
    const unitSelect = unitWrap.querySelector('select');
    asset.units.forEach(function (unit) {
      const opt = document.createElement('option');
      opt.value = unit.id;
      opt.textContent = unit.label;
      unitSelect.appendChild(opt);
    });
    row.appendChild(unitWrap);

    const estimated = document.createElement('div');
    estimated.className = 'estimated';
    estimated.dataset.field = 'estimated';
    estimated.textContent = asset.priced ? 'Estimated: —' : 'Value in selected currency';
    row.appendChild(estimated);

    const amountInput = row.querySelector('[data-field="amount"]');
    const holding = portfolio.holdings[asset.id];
    amountInput.value = holding.amount;
    unitSelect.value = holding.unit;

    function sync() {
      portfolio.holdings[asset.id] = {
        amount: amountInput.value,
        unit: unitSelect.value
      };
      setDirty(true);
      renderEstimates();
      renderTotals();
    }

    amountInput.addEventListener('input', sync);
    unitSelect.addEventListener('change', sync);

    return row;
  }

  function renderEstimates() {
    const currency = portfolio.summaryCurrency;
    ASSETS.forEach(function (asset) {
      const row = grid.querySelector('[data-asset-id="' + asset.id + '"]');
      if (!row) return;
      const est = row.querySelector('[data-field="estimated"]');
      if (!asset.priced) {
        const holding = portfolio.holdings[asset.id];
        const amount = parseAmount(holding.amount);
        if (amount <= 0) {
          est.textContent = 'Enter amount';
          return;
        }

        const value = estimateValue(asset, holding, currency);
        const native = formatMoney(amount, holding.unit.toUpperCase());
        est.textContent = value == null
          ? native
          : 'Estimated: ' + formatMoney(value, currency) + ' (' + native + ')';
        return;
      }

      const value = estimateValue(asset, portfolio.holdings[asset.id], currency);
      est.textContent = value == null
        ? 'Estimated: —'
        : 'Estimated: ' + formatMoney(value, currency);
    });
  }

  function renderTotals() {
    const currency = portfolio.summaryCurrency;
    let pricedTotal = 0;
    let pricedCount = 0;
    const nativeTotals = {};

    ASSETS.forEach(function (asset) {
      const holding = portfolio.holdings[asset.id];
      const amount = parseAmount(holding.amount);
      if (amount <= 0) return;

      if (asset.priced) {
        const value = estimateValue(asset, holding, currency);
        if (value != null) {
          pricedTotal += value;
          pricedCount += 1;
        }
      } else if (asset.type === 'fiat') {
        const code = holding.unit.toUpperCase();
        nativeTotals[code] = (nativeTotals[code] || 0) + amount;
        const value = estimateValue(asset, holding, currency);
        if (value != null) {
          pricedTotal += value;
          pricedCount += 1;
        }
      }
    });

    totalsEl.innerHTML = '';

    function addRow(label, value) {
      const dt = document.createElement('dt');
      dt.textContent = label;
      const dd = document.createElement('dd');
      dd.textContent = value;
      totalsEl.appendChild(dt);
      totalsEl.appendChild(dd);
    }

    addRow('Estimated total in ' + currency, formatMoney(pricedTotal, currency));
    addRow('Assets with estimates', String(pricedCount));

    FIATS.forEach(function (fiat) {
      if (nativeTotals[fiat]) {
        addRow('Stocks, cash & property in ' + fiat, formatMoney(nativeTotals[fiat], fiat));
      }
    });
  }

  function renderGrid() {
    grid.innerHTML = '';
    ASSETS.forEach(function (asset) {
      grid.appendChild(buildRow(asset));
    });
  }

  async function loadPortfolioFromServer() {
    const res = await fetch('/api/portfolio.json', { cache: 'no-store' });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    applyPortfolioData(await res.json());
  }

  async function loadSpotPrices() {
    const res = await fetch('/api/spot_prices.json', { cache: 'no-store' });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    spotData = await res.json();
    statusEl.textContent = 'Spot prices updated ' + (spotData.updated_at || '—') +
      '. BullionVault quotes are per kg; crypto quotes are per coin.' +
      (spotData.fx_reference ? ' FX uses ' + spotData.fx_reference + ' cross-rates.' : '');
  }

  async function savePortfolioToServer() {
    syncFormToPortfolio();
    saveButton.disabled = true;
    saveStatusEl.textContent = 'Saving…';

    try {
      const res = await fetch('/api/portfolio.json', {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          summary_currency: portfolio.summaryCurrency,
          holdings: portfolio.holdings
        })
      });
      const data = await res.json();
      if (!res.ok || !data.ok) throw new Error(data.error || ('HTTP ' + res.status));

      if (data.portfolio) applyPortfolioData(data.portfolio);
      renderGrid();
      renderEstimates();
      renderTotals();
      setDirty(false);
      saveStatusEl.textContent = 'Saved' + (data.portfolio && data.portfolio.updated_at
        ? ' at ' + data.portfolio.updated_at
        : '');
      await loadPortfolioHistory();
      renderPortfolioCharts();
    } catch (e) {
      saveStatusEl.textContent = 'Save failed: ' + (e && e.message ? e.message : String(e));
    } finally {
      saveButton.disabled = false;
    }
  }

  function monthKey(epochSeconds) {
    const d = new Date(epochSeconds * 1000);
    return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0');
  }

  function filterHistoryPoints(points, rangeId, nowSeconds) {
    if (!points || !points.length) return [];

    if (rangeId === 'year') {
      const buckets = new Map();
      points.forEach(function (p) {
        const key = monthKey(p[0]);
        const existing = buckets.get(key);
        if (!existing || p[0] > existing[0]) buckets.set(key, p);
      });
      return Array.from(buckets.values()).sort(function (a, b) { return a[0] - b[0]; }).slice(-12);
    }

    const days = rangeId === 'day' ? 1 : 31;
    const cutoff = nowSeconds - (days * SECONDS_PER_DAY);
    return points.filter(function (p) { return p[0] >= cutoff; });
  }

  function formatHistoryLabel(epochSeconds, rangeId) {
    const d = new Date(epochSeconds * 1000);
    if (rangeId === 'day') return d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
    if (rangeId === 'year') return d.toLocaleDateString([], { month: 'short', year: 'numeric' });
    return d.toLocaleDateString([], { month: 'short', day: 'numeric' });
  }

  function destroyPortfolioCharts() {
    chartInstances.forEach(function (chart) { chart.destroy(); });
    chartInstances = [];
    if (chartsHost) chartsHost.innerHTML = '';
  }

  function buildHistoryChart(title, valuesByCurrency, nowSeconds) {
    if (typeof Chart === 'undefined') return null;

    const currencies = FIATS.filter(function (code) {
      const key = code.toLowerCase();
      return valuesByCurrency[key] && valuesByCurrency[key].length;
    });
    if (!currencies.length) return null;

    const reference = currencies.reduce(function (best, code) {
      const points = filterHistoryPoints(valuesByCurrency[code.toLowerCase()], historyRange, nowSeconds);
      return points.length > best.length ? points : best;
    }, filterHistoryPoints(valuesByCurrency[currencies[0].toLowerCase()], historyRange, nowSeconds));

    if (!reference.length) return null;

    const div = document.createElement('div');
    div.className = 'card';
    const h = document.createElement('h3');
    h.textContent = title;
    div.appendChild(h);
    const canvas = document.createElement('canvas');
    div.appendChild(canvas);
    chartsHost.appendChild(div);

    const datasets = currencies.map(function (code) {
      const points = filterHistoryPoints(valuesByCurrency[code.toLowerCase()], historyRange, nowSeconds);
      const byTime = new Map(points.map(function (p) { return [p[0], p[1]]; }));
      return {
        label: code,
        data: reference.map(function (p) { return byTime.get(p[0]) ?? null; }),
        borderColor: CURRENCY_COLORS[code],
        backgroundColor: CURRENCY_COLORS[code] + '22',
        spanGaps: true,
        tension: 0.2,
        pointRadius: reference.length < 2 ? 4 : 1
      };
    });

    const chart = new Chart(canvas.getContext('2d'), {
      type: 'line',
      data: {
        labels: reference.map(function (p) { return formatHistoryLabel(p[0], historyRange); }),
        datasets: datasets
      },
      options: {
        responsive: true,
        maintainAspectRatio: true,
        aspectRatio: 1.5,
        plugins: { legend: { labels: { color: '#8b949e' } } },
        scales: {
          x: { ticks: { color: '#8b949e', maxTicksLimit: historyRange === 'year' ? 12 : 8 } },
          y: { ticks: { color: '#8b949e' } }
        }
      }
    });
    chartInstances.push(chart);
    return chart;
  }

  function renderPortfolioCharts() {
    destroyPortfolioCharts();
    if (!chartsHost) return;

    if (!portfolioHistory || !portfolioHistory.snapshot_count) {
      historyStatusEl.textContent = 'No portfolio history yet. Save your portfolio or wait for a background scrape.';
      return;
    }

    const nowSeconds = Math.floor(Date.now() / 1000);
    historyStatusEl.textContent = 'Snapshots stored: ' + portfolioHistory.snapshot_count +
      ' — retention ' + portfolioHistory.retention_days + ' days';

    buildHistoryChart('Total portfolio', portfolioHistory.totals || {}, nowSeconds);
    (portfolioHistory.assets || []).forEach(function (asset) {
      buildHistoryChart(asset.label || asset.id, asset.values || {}, nowSeconds);
    });

    if (!chartInstances.length) {
      historyStatusEl.textContent = 'No history points in the selected range.';
    }
  }

  async function loadPortfolioHistory() {
    const res = await fetch('/api/portfolio_history.json', { cache: 'no-store' });
    if (!res.ok) throw new Error('HTTP ' + res.status);
    portfolioHistory = await res.json();
  }

  if (historyRangeEl) {
    historyRangeEl.addEventListener('click', function (event) {
      const btn = event.target.closest('button[data-range]');
      if (!btn) return;
      historyRange = btn.dataset.range;
      historyRangeEl.querySelectorAll('button').forEach(function (b) { b.classList.remove('active'); });
      btn.classList.add('active');
      renderPortfolioCharts();
    });
  }

  summaryCurrencyEl.addEventListener('change', function () {
    portfolio.summaryCurrency = summaryCurrencyEl.value;
    setDirty(true);
    renderEstimates();
    renderTotals();
  });

  saveButton.addEventListener('click', savePortfolioToServer);

  async function init() {
    try {
      await loadPortfolioFromServer();
    } catch (e) {
      statusEl.textContent = 'Could not load saved portfolio: ' + (e && e.message ? e.message : String(e));
    }

    renderGrid();
    setDirty(false);

    try {
      await loadSpotPrices();
    } catch (e) {
      statusEl.textContent = 'Could not load spot prices: ' + (e && e.message ? e.message : String(e));
    }

    renderEstimates();
    renderTotals();

    try {
      await loadPortfolioHistory();
      renderPortfolioCharts();
    } catch (e) {
      if (historyStatusEl) {
        historyStatusEl.textContent = 'Could not load portfolio history: ' + (e && e.message ? e.message : String(e));
      }
    }
  }

  init();
})();
