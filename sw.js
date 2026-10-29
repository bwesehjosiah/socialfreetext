const CACHE_NAME='socialfreetext-shell-v1';
self.addEventListener('install',event=>{self.skipWaiting()});
self.addEventListener('activate',event=>{event.waitUntil((async()=>{await self.clients.claim();const clientsList=await self.clients.matchAll({type:'window',includeUncontrolled:true});})())});
self.addEventListener('push',event=>{
 let data={title:'SocialfreeText',body:'You have a new notification.',url:'/',kind:'message'};
 try{if(event.data)data={...data,...event.data.json()}}catch{try{data.body=event.data?.text()||data.body}catch{}}
 event.waitUntil(self.registration.showNotification(data.title||'SocialfreeText',{
  body:data.body||'You have a new notification.',
  icon:data.icon||'/icon-192.png',
  badge:data.badge||'/icon-192.png',
  tag:data.tag||'sft-push-'+Date.now(),
  renotify:true,
  requireInteraction:data.kind==='call'||data.type==='call'||!!data.requireInteraction,
  vibrate:(data.kind==='call'||data.type==='call')?[500,250,500,250,900]:[250,150,250],
  silent:false,
  actions:(data.kind==='call'||data.type==='call')?[{action:'open-app',title:'Open SocialfreeText'},{action:'dismiss',title:'Dismiss'}]:[{action:'open-app',title:'Open message'}],
  data:{url:data.url||'/',type:data.kind||data.type||'message',callId:data.callId||null}
 }));
});
self.addEventListener('notificationclick',event=>{
 event.notification.close();
 if(event.action==='dismiss')return;
 const target=new URL(event.notification.data?.url||'/',self.location.origin).href;
 event.waitUntil((async()=>{
  const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});
  for(const client of windows){if(new URL(client.url).origin===self.location.origin){if('focus'in client){await client.focus();if('navigate'in client&&client.url!==target)await client.navigate(target)}client.postMessage({type:'SFT_NOTIFICATION_CLICK',notification:event.notification.data||{}});return}}
  if(self.clients.openWindow)await self.clients.openWindow(target);
 })());
});
self.addEventListener('pushsubscriptionchange',event=>{
 event.waitUntil((async()=>{
  // The page re-registers changed subscriptions when the user next opens it.
  const windows=await self.clients.matchAll({type:'window',includeUncontrolled:true});
  windows.forEach(client=>client.postMessage({type:'SFT_PUSH_SUBSCRIPTION_CHANGED'}));
 })());
});
