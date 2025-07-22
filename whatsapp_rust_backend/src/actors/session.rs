use crate::actors::server::{ChatServer, ClientMessage, Connect, Disconnect, 
Typing, WsMessage};
use actix::{fut, Actor, ActorContext, ActorFutureExt, Addr, AsyncContext, 
ContextFutureSpawner, Handler, Running, StreamHandler, WrapFuture};
use actix_web_actors::ws;
use serde::Deserialize;
use std::time::{Duration, Instant};
use uuid::Uuid;

const HEARTBEAT_INTERVAL: Duration = Duration::from_secs(5);
const CLIENT_TIMEOUT: Duration = Duration::from_secs(10);

#[derive(Deserialize, Debug)]
#[serde(tag = "event", content = "data", rename_all = "snake_case")]
enum WsClientEvent {
    Message(MessagePayload),
    Typing(TypingPayload),
}

#[derive(Deserialize, Debug)]
struct MessagePayload { conversation_id: Uuid, content: String }
#[derive(Deserialize, Debug)]
struct TypingPayload { conversation_id: Uuid, is_typing: bool }

pub struct WebSocketSession { pub user_id: Uuid, pub hb: Instant, pub server_addr: 
Addr<ChatServer> }
impl WebSocketSession {
    pub fn new(user_id: Uuid, server_addr: Addr<ChatServer>) -> Self { Self { 
user_id, hb: Instant::now(), server_addr } }
    fn hb(&self, ctx: &mut ws::WebsocketContext<Self>) {
        ctx.run_interval(HEARTBEAT_INTERVAL, |act, ctx| {
            if Instant::now().duration_since(act.hb) > CLIENT_TIMEOUT { 
ctx.stop(); } else { ctx.ping(b""); }
        });
    }
}
impl Actor for WebSocketSession {
    type Context = ws::WebsocketContext<Self>;
    fn started(&mut self, ctx: &mut Self::Context) {
        self.hb(ctx);
        self.server_addr.send(Connect { user_id: self.user_id, addr: 
ctx.address().recipient() })
            .into_actor(self).then(|r, _, c| { if r.is_err() { c.stop(); } 
fut::ready(()) }).wait(ctx);
    }
    fn stopping(&mut self, _: &mut Self::Context) -> Running {
        self.server_addr.do_send(Disconnect { user_id: self.user_id });
        Running::Stop
    }
}
impl Handler<WsMessage> for WebSocketSession { type Result = (); fn handle(&mut 
self, msg: WsMessage, ctx: &mut Self::Context) { ctx.text(msg.0); } }
impl StreamHandler<Result<ws::Message, ws::ProtocolError>> for WebSocketSession {
    fn handle(&mut self, msg: Result<ws::Message, ws::ProtocolError>, ctx: &mut 
Self::Context) {
        match msg {
            Ok(ws::Message::Ping(msg)) => { self.hb = Instant::now(); 
ctx.pong(&msg); },
            Ok(ws::Message::Pong(_)) => { self.hb = Instant::now(); },
            Ok(ws::Message::Text(text)) => match 
serde_json::from_str::<WsClientEvent>(&text) {
                Ok(WsClientEvent::Message(p)) => 
self.server_addr.do_send(ClientMessage { sender_id: self.user_id, conversation_id: 
p.conversation_id, content: p.content }),
                Ok(WsClientEvent::Typing(p)) => self.server_addr.do_send(Typing { 
sender_id: self.user_id, conversation_id: p.conversation_id, is_typing: 
p.is_typing }),
                Err(e) => log::warn!("Unknown WS event from {}: {}", self.user_id, 
e),
            },
            Ok(ws::Message::Close(reason)) => { ctx.close(reason); ctx.stop(); },
            _ => ctx.stop(),
        }
    }
}
