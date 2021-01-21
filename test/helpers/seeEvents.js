module.exports = async (promise, events) => {
  let logs = (await promise).logs;
  if (logs === undefined)
  {
    assert.equal(events.length, 0, "didn't get any event, expected " + events);
  }
  else
  {
    assert.deepEqual(logs.map(l => l.event), events);
  }
};
