module.exports = async (promise) => {
  try {
    await promise;
    // Don't include 'revert' in the message, because we scan for that
    assert.fail('succeeded');
  } catch (error) {
    const revertFound = error.message.search('revert') >= 0;
    assert(revertFound, `Expected "revert", got ${error} instead`);
  }
};
