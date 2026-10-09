const fail=message=>{throw Object.assign(new Error(message),{status:400});};
function invoicePayload(body){
  const fields=['studentId','companyId','recordId','invoiceNumber','description','amount','currency','dueDate'];
  if(!body || Array.isArray(body) || Object.keys(body).some(key=>!fields.includes(key)))fail('Invalid invoice fields');
  for(const key of ['companyId','recordId'])if(typeof body[key]!=='string' || !/^[\w-]{1,100}$/.test(body[key]))fail('Invalid invoice identity');
  for(const key of ['invoiceNumber','description'])if(typeof body[key]!=='string' || !body[key].trim() || body[key].length>1000)fail('Invalid invoice text');
  if(typeof body.amount!=='number' || !Number.isFinite(body.amount) || body.amount<=0)fail('Invalid invoice amount');
  if(typeof body.currency!=='string' || !['USD','EUR','TRY','GBP','SAR','AED','EGP'].includes(body.currency))fail('Unsupported currency');
  if(body.dueDate && (typeof body.dueDate!=='string' || Number.isNaN(Date.parse(body.dueDate))))fail('Invalid due date');
  return body;
}
function paymentPayload(body,total){
  if(!body || Object.keys(body).some(key=>!['paidAmount','version'].includes(key)) || !Number.isInteger(body.version) || body.version<0 || typeof body.paidAmount!=='number' || !Number.isFinite(body.paidAmount) || body.paidAmount<0 || body.paidAmount>total)fail('Invalid payment balance');
  return {paidAmount:body.paidAmount,version:body.version,status:body.paidAmount>=total?'paid':'unpaid'};
}
module.exports={invoicePayload,paymentPayload};
