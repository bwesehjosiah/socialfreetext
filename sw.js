const CACHE_NAME='socialfreetext-shell-v2';
self.addEventListener('install',event=>{self.skipWaiting()});
self.addEventListener('activate',event=>{event.waitUntil((async()=>{await self.clients.claim();})())});
self.addEventListener('push',event=>{
 let data={title:'SocialfreeText',body:'You have a new notification.',url:'/',kind:'message'};
 try{if(event.data)data={...data,...event.data.json()}}catch{try{data.body=event.data?.text()||data.body}catch{}}
 const isCall=data.kind==='call'||data.type==='call';
 const options={
  body:data.body||'You have a new notification.',
  icon:data.icon||'/icon-192.png',
  badge:data.badge||'/icon-192.png',
  tag:data.tag||(isCall?'sft-incoming-call':'sft-message-'+Date.now()),
  renotify:true,
  requireInteraction:isCall||!!data.requireInteraction,
  vibrate:isCall?[1000,400,1000,400,1400,500,1400]:[300,180,300],
  silent:false,
  timestamp:Date.now(),
  actions:isCall?[{action:'open-call',title:'Open call'},{action:'dismiss',title:'Dismiss'}]:[{action:'reply',title:'Reply'},{action:'dismiss',title:'Dismiss'}],
  data:{url:data.url||'/',type:isCall?'call':'message',callId:data.callId||null}
 };
 event.waitUntil(self.registration.showNotification(data.title||'SocialfreeText',options));
});
self.addEventListener('notificationclick',event=>{
 event.notification.close();
 if(event.action==='dismiss')return;
 const data=event.notification.data||{};
 const target=data.type==='call'?'/?open=calls':'/?open=chats&reply=1';
 const absolute=new URL(target,self.location.origin).href;
 event.waitUntil((async()=>{
  const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});
  for(const client of windows){
   if(new URL(client.url).origin===self.location.origin){
    if('focus'in client)await client.focus();
    if('navigate'in client&&client.url!==absolute)await client.navigate(absolute);
    client.postMessage({type:'SFT_NOTIFICATION_CLICK',notification:data,action:event.action});
    return;
   }
  }
  if(self.clients.openWindow)await self.clients.openWindow(absolute);
 })());
});
self.addEventListener('pushsubscriptionchange',event=>{
 event.waitUntil((async()=>{
  const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});
  windows.forEach(client=>client.postMessage({type:'SFT_PUSH_SUBSCRIPTION_CHANGED'}));
 })());
});
