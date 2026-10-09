const test=require('node:test');
const assert=require('node:assert/strict');
const {invoicePayload,paymentPayload}=require('../src/utils/crmFinancePolicy');
const {invoicePaid,invoiceRemaining}=require('../src/utils/invoiceBalance');
test('CRM invoices reject invalid money, currencies and injected status changes',()=>{
  const body={studentId:'a'.repeat(24),companyId:'company',recordId:'INV-1',invoiceNumber:'INV-1',description:'Fees',amount:1000,currency:'USD'};
  assert.equal(invoicePayload(body).amount,1000);
  for(const invalid of [{amount:-1},{amount:Infinity},{currency:'INVALID'},{status:'paid'},{companyId:'../other'}])assert.throws(()=>invoicePayload({...body,...invalid}));
  assert.throws(()=>paymentPayload({paidAmount:1001,version:0},1000));assert.throws(()=>paymentPayload({paidAmount:100,version:-1},1000));
  assert.equal(paymentPayload({paidAmount:1000,version:0},1000).status,'paid');
});
test('CRM and wallet payments reduce the remaining invoice without being counted twice when fully paid',()=>{
  const invoice={amount:1000,status:'unpaid',crmPaidAmount:300,walletCreditApplied:50};
  assert.equal(invoicePaid(invoice),350);assert.equal(invoiceRemaining(invoice),650);
  assert.equal(invoicePaid({...invoice,status:'paid'}),1000);assert.equal(invoiceRemaining({...invoice,status:'paid'}),0);
});
