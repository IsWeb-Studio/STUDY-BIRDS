function invoicePaid(invoice){return invoice.status==='paid'?Number(invoice.amount || 0):Math.min(Number(invoice.amount || 0),Number(invoice.crmPaidAmount || 0)+Number(invoice.walletCreditApplied || 0));}
function invoiceRemaining(invoice){return Math.max(0,Number(invoice.amount || 0)-invoicePaid(invoice));}
module.exports={invoicePaid,invoiceRemaining};
