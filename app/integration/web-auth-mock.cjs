const http = require('node:http');
let enabled=false, verified=false;
http.createServer(async (req,res)=>{
 res.setHeader('Access-Control-Allow-Origin','http://127.0.0.1:4173');res.setHeader('Access-Control-Allow-Headers','authorization,content-type,x-study-birds-client');res.setHeader('Access-Control-Allow-Methods','GET,POST,DELETE,OPTIONS');res.setHeader('Content-Type','application/json');
 if(req.method==='OPTIONS'){res.writeHead(204);return res.end();}
 let body='';for await(const chunk of req)body+=chunk;const data=body?JSON.parse(body):{};let result={};let status=200;
 const user={_id:'test-user',name:'Test Student',email:'test@example.test',role:'student',emailVerified:verified};
 if(req.url==='/api/identity/config')result={passkeys:true,apple:true,phone:true,appleClientId:'test',appleRedirectUri:'https://example.test/login'};
 else if(req.url==='/api/identity/passkeys')result=[];
 else if(req.url==='/api/auth/me') result={user};
 else if(req.url==='/api/auth/login'){if(data.twoFactorCode==='123456')result={token:'test-token',user};else {status=data.twoFactorCode?400:428;result={requiresTwoFactor:true,message:data.twoFactorCode?'Invalid code':'Enter the emailed code'};}}
 else if(req.url.endsWith('/two-factor')&&req.method==='GET')result={enabled};
 else if(req.url.endsWith('/sessions'))result=[{_id:'test-session',device:'Test browser',lastSeen:new Date().toISOString(),current:true}];
 else if(req.url.endsWith('/confirm')){if(data.code!=='123456'){status=400;result={message:'Invalid code'};}else {if(req.url.includes('two-factor'))enabled=data.enabled;verified=true;result={enabled,emailVerified:verified};}}
 else if(req.url.includes('site-settings'))result={};
 res.writeHead(status);res.end(JSON.stringify(result));
}).listen(5000,'127.0.0.1',()=>console.log('Isolated auth mock on 5000'));
