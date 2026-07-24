const express    = require('express');
const router     = express.Router();
const protect    = require('../middleware/auth.middleware');
const walletCtrl = require('../controllers/wallet.controller');

router.get('/',                  protect, walletCtrl.getWallet);
router.post('/cards',            protect, walletCtrl.addCard);
router.delete('/cards/:cardId',  protect, walletCtrl.removeCard);
router.post('/pay',              protect, walletCtrl.payWithWallet);
router.post('/withdraw',         protect, walletCtrl.withdraw);
router.put('/bank-account',      protect, walletCtrl.updateBankAccount);

module.exports = router;
