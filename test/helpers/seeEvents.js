module.exports = async (promise, events) => {
  let logs = (await promise).logs;
  if (logs === undefined)
  {
    assert.equal(events.length, 0, "didn't get any event, expected " + events);
  }
  else
  {
    for (var i = 0; i < events.length; i++)
    {
      assert.isTrue(undefined !== logs.find(e => e.event === events[i]),
                    "expected to see " + events[i]);
    }
    for (var i = 0; i < logs.length; i++)
    {
      assert.isTrue(undefined !== events.find(e => e === logs[i].event),
                    "didn't expect to see " + logs[i].event);
    }
  }
};
