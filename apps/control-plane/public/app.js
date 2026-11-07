(function () {
  'use strict';

  async function postJson(url, data, csrf) {
    const headers = { 'Content-Type': 'application/json', Accept: 'application/json' };
    if (csrf) headers['X-ARSY-CSRF'] = csrf;
    const response = await fetch(url, {
      method: 'POST',
      credentials: 'same-origin',
      headers,
      body: JSON.stringify(data || {})
    });
    const result = await response.json().catch(function () { return {}; });
    if (!response.ok) throw new Error(result.error || 'Request failed.');
    return result;
  }

  document.querySelectorAll('[data-api-form]').forEach(function (form) {
    form.addEventListener('submit', async function (event) {
      event.preventDefault();
      const message = form.querySelector('.form-message');
      const button = form.querySelector('button[type="submit"]');
      const data = Object.fromEntries(new FormData(form).entries());
      if (data.password && data.password.length < 14) {
        message.textContent = 'Password wajib minimal 14 karakter.';
        message.classList.add('error');
        return;
      }
      if (data.password && data.passwordConfirm !== data.password) {
        message.textContent = 'Konfirmasi password tidak cocok.';
        message.classList.add('error');
        return;
      }
      message.textContent = 'Memproses...';
      message.classList.remove('error');
      button.disabled = true;
      try {
        const result = await postJson(form.dataset.apiForm, data);
        message.textContent = result.message || 'Berhasil.';
        window.location.assign(result.redirect || '/dashboard');
      } catch (error) {
        message.textContent = error.message;
        message.classList.add('error');
        button.disabled = false;
      }
    });
  });

  const logout = document.querySelector('[data-logout]');
  if (logout) {
    logout.addEventListener('submit', async function (event) {
      event.preventDefault();
      const csrf = document.querySelector('meta[name="csrf-token"]').content;
      try {
        const result = await postJson('/api/auth/logout', {}, csrf);
        window.location.assign(result.redirect || '/login');
      } catch (error) {
        window.alert(error.message);
      }
    });
  }


  const onboardingForm = document.getElementById('onboarding-form');
  if (onboardingForm) {
    (async function () {
    const csrf = document.querySelector('meta[name="csrf-token"]').content;
    const mode = document.getElementById('access-mode');
    const domainFields = document.getElementById('domain-fields');
    const syncMode = function () { domainFields.hidden = mode.value === 'private'; };
    mode.addEventListener('change', syncMode); syncMode();
    const saved = await fetch('/api/onboarding/profile', { credentials: 'same-origin' }).then(r => r.json()).catch(() => null);
    if (saved && saved.profile) {
      Object.entries(saved.profile).forEach(([key, value]) => {
        const field = onboardingForm.elements.namedItem(key);
        if (!field) return;
        if (field.type === 'checkbox') field.checked = Boolean(value);
        else field.value = value;
      });
      syncMode();
    }
    const dnsButton = document.getElementById('dns-check');
    dnsButton.addEventListener('click', async function () {
      const resultBox = document.getElementById('dns-result');
      resultBox.textContent = 'Memeriksa DNS...';
      try {
        const result = await postJson('/api/onboarding/dns-check', {
          hostname: onboardingForm.elements.hostname.value,
          targetIpv4: onboardingForm.elements.targetIpv4.value
        }, csrf);
        resultBox.textContent = 'A: ' + (result.a.join(', ') || '—') + ' · AAAA: ' + (result.aaaa.join(', ') || '—') +
          (result.matches === null ? '' : result.matches ? ' · IPv4 cocok' : ' · IPv4 belum cocok');
      } catch (error) { resultBox.textContent = error.message; }
    });
    onboardingForm.addEventListener('submit', async function (event) {
      event.preventDefault();
      const message = document.getElementById('wizard-message');
      const data = Object.fromEntries(new FormData(onboardingForm).entries());
      data.proxyTls = onboardingForm.elements.proxyTls.checked;
      message.textContent = 'Menyimpan profil...';
      try {
        const result = await postJson('/api/onboarding/profile', data, csrf);
        message.textContent = result.message;
        if (result.nextStep) window.alert(result.nextStep);
        window.location.assign(result.redirect || '/dashboard');
      } catch (error) { message.textContent = error.message; message.classList.add('error'); }
    });
    })();
  }

  const nodeTime = document.getElementById('node-time');
  if (nodeTime) {
    const timezone = nodeTime.dataset.timezone || 'Asia/Jakarta';
    try {
      const formatter = new Intl.DateTimeFormat(undefined, {
        timeZone: timezone,
        dateStyle: 'medium',
        timeStyle: 'short'
      });
      const renderNodeTime = function () { nodeTime.textContent = formatter.format(new Date()); };
      renderNodeTime();
      window.setInterval(renderNodeTime, 60000);
    } catch {
      nodeTime.textContent = 'Invalid timezone';
    }
  }

  const updateCard = document.getElementById('update-card');
  if (updateCard) {
    const updateCopy = document.getElementById('update-copy');
    const updateCommand = document.getElementById('update-command');
    const updateNow = document.getElementById('update-now');
    const updateLater = document.getElementById('update-later');
    const copyButton = document.getElementById('copy-update');
    const csrf = document.querySelector('meta[name="csrf-token"]').content;
    let approvedCommand = '';

    fetch('/api/update/check', { credentials: 'same-origin', cache: 'no-store' })
      .then(function (response) { return response.json(); })
      .then(function (result) {
        if (!result.ok) return;
        if (!result.available) return;
        updateCopy.textContent = 'Installed ' + result.installedSha.slice(0, 12) +
          ' · Available ' + result.availableSha.slice(0, 12) + ' — ' + result.message +
          '. Nothing changes until you approve.';
        updateCard.hidden = false;
      })
      .catch(function () {});

    updateLater.addEventListener('click', function () {
      updateCard.hidden = true;
    });

    updateNow.addEventListener('click', async function () {
      if (!window.confirm('Approve this A-R-S-Y update? The VPS will not change until you run the command shown next.')) return;
      updateNow.disabled = true;
      updateNow.textContent = 'Checking...';
      try {
        const result = await postJson('/api/update/approve', {}, csrf);
        approvedCommand = result.command;
        updateCommand.textContent = approvedCommand;
        updateCommand.hidden = false;
        copyButton.hidden = false;
        updateCopy.textContent = result.message;
        updateNow.textContent = 'Approved';
      } catch (error) {
        updateCopy.textContent = error.message;
        updateNow.disabled = false;
        updateNow.textContent = 'Review update';
      }
    });

    copyButton.addEventListener('click', async function () {
      if (!approvedCommand) return;
      try {
        await navigator.clipboard.writeText(approvedCommand);
        copyButton.textContent = 'Copied';
      } catch {
        copyButton.textContent = 'Copy unavailable';
      }
    });
  }
})();
