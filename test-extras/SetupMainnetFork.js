
const { spawn } = require('child_process');
const Web3 = require('web3');

const node = 'https://mainnet.infura.io/v3/2599df54929b47099bda360958d75aaf';
const web3 = new Web3(node);

const template = {
  to: '0x223c067F8CF28ae173EE5CafEa60cA44C335fecB',
  data: web3.utils.sha3('getOwner(uint32)').slice(0, 10)
        + '00000000000000000000000000000000000000000000000000000000000000'
};

async function go() {
  console.log('setting up...');
  let senators = [];
  for (let i = 0; i < 129; i++) {
    let hex = i.toString(16);
    if (hex.length == 1) hex = '0' + hex;
    const callObj = {
      ...template,
      data: template.data + hex
    }
    const res = await web3.eth.call(callObj);
    senators.push('0x' + res.slice(26));
  }
  senators = [...new Set(senators)];
  const unlocks = senators.reduce((acc, cur) => {
    if (typeof acc === 'string') acc = ['--unlock', acc];
    acc.push('--unlock');
    acc.push(cur);
    return acc;
  });

  spawn('ganache-cli', ['--fork', node, ...unlocks]);

  console.log('ready!');
  return;
}

return go();
