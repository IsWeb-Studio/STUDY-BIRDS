// Opt-in pagination preserves the existing website array responses.
function crmPagination(query) {
 if(query.crmPagination!=='1')return null;
 const page=Math.max(1,parseInt(query.page,10)||1),limit=Math.min(100,Math.max(1,parseInt(query.limit,10)||100));
 return {page,limit,skip:(page-1)*limit};
}
function crmPage(items,total,{page,limit}) {
 const totalPages=Math.max(1,Math.ceil(total/limit));
 return {items,pagination:{page,limit,total,totalPages,hasNextPage:page<totalPages}};
}
module.exports={crmPagination,crmPage};
