const {
  logContract,
  logger
} = require('./utils');


const main = async () => {
  const [keyPair] = await locklift.keys.getKeyPairs();
  const Sample = await locklift.factory.getAccount('Sample');

  logger.log('Deploying Sample');
  let sample = await locklift.giver.deployContract({
    contract: Sample,
    constructorParams: {
      owner: '',
    },
    initParams: {
      randomNonce: locklift.utils.getRandomNonce(),
    },
    keyPair
  }, locklift.utils.convertCrystal(5, 'nano'));
  await logContract(sample);
};


main()
  .then(() => process.exit(0))
  .catch(e => {
    console.log(e);
    process.exit(1);
  });
