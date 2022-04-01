const {
  logContract,
  logger
} = require('../scripts/utils');
const {expect} = require('chai');

const [keyPair] = await locklift.keys.getKeyPairs();

describe('Test Sample contract', async function () {
  let sample;
  it('Setup Sample', async () => {
    const Sample = await locklift.factory.getAccount('Sample');
    sample = await locklift.giver.deployContract({
      contract: Sample,
      constructorParams: {},
      initParams: {
        randomNonce: locklift.utils.getRandomNonce(),
      },
      keyPair
    }, locklift.utils.convertCrystal(5, 'nano'));
    await logContract(sample);

  })
  it('Check value', async () => {
    expect((await locklift.ton.getBalance(sample.address)).toString())
      .to.be.not.equal('0', 'Account balance is zero')
  })

})