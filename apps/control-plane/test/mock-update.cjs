const nativeFetch = globalThis.fetch.bind(globalThis);

globalThis.fetch = async function (input, init) {
  const target = typeof input === 'string' || input instanceof URL ? String(input) : input.url;
  if (target === 'https://api.github.com/repos/bjo163/a-r-s-y/commits/main') {
    const sha = process.env.ARSY_TEST_UPDATE_SHA || 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    return new Response(JSON.stringify({
      sha,
      html_url: 'https://github.com/bjo163/a-r-s-y/commit/' + sha,
      commit: { message: process.env.ARSY_TEST_UPDATE_MESSAGE || 'integration test update' }
    }), { status: 200, headers: { 'content-type': 'application/json' } });
  }
  return nativeFetch(input, init);
};
