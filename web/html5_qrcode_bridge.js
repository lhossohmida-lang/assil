(function () {
  const active = new Map();

  function config() {
    return {
      fps: 12,
      qrbox: { width: 300, height: 180 },
      aspectRatio: 1.777778,
      rememberLastUsedCamera: true,
    };
  }

  async function start(elementId, onSuccess, onError) {
    if (!window.Html5Qrcode) {
      throw new Error('html5-qrcode library is not loaded');
    }

    const scanner = new Html5Qrcode(elementId, {
      verbose: false,
      experimentalFeatures: { useBarCodeDetectorIfSupported: true },
    });
    active.set(elementId, scanner);

    const success = (text) => onSuccess(String(text));
    const failure = (error) => onError(String(error || 'not found'));
    const options = config();

    try {
      await scanner.start({ facingMode: { exact: 'environment' } }, options, success, failure);
    } catch (firstError) {
      // Desktop webcams may not expose an environment-facing camera.
      try {
        await scanner.start({ facingMode: 'environment' }, options, success, failure);
      } catch (secondError) {
        active.delete(elementId);
        throw secondError || firstError;
      }
    }
  }

  async function stop(elementId) {
    const scanner = active.get(elementId);
    if (!scanner) return;
    active.delete(elementId);
    try { await scanner.stop(); } finally { scanner.clear(); }
  }

  window.KmsanHtml5Qr = { start, stop };
})();
