use actix::{Actor, ActorFutureExt, AsyncContext, Context, ContextFutureSpawner, 
Handler, Message as ActixMessage, Recipient, WrapFuture};
use serde::Serialize;
use serde_json::json;
use sqlx::PgPool;
use std::collections::{HashMap, HashSet};
use uuid::Uuid;
use actix::fut;

#[derive(ActixMessage, Debug, Serialize)] #[rtype(result = "()")] pub struct 
ClientMessage { pub sender_id: Uuid, pub conversation_id: Uuid, pub content: 
String }
#[derive(ActixMessage, Debug)] #[rtype(result = "()")] pub struct Connect { pub 
user_id: Uuid, pub addr: Recipient<WsMessage> }
#[derive(ActixMessage, Debug)] #[rtype(result = "()")] pub struct Disconnect { pub 
user_id: Uuid }
#[derive(ActixMessage, Debug, Serialize)] #[rtype(result = "()")] pub struct 
Typing { pub sender_id: Uuid, pub conversation_id: Uuid, pub is_typing: bool }
#[derive(ActixMessage, Debug, Serialize)] #[rtype(result = "()")] pub struct 
WsMessage(pub String);

pub struct ChatServer { sessions: HashMap<Uuid, Recipient<WsMessage>>, 
conversations: HashMap<Uuid, HashSet<Uuid>>, db_pool: PgPool }
impl ChatServer {
    pub fn new(db_pool: PgPool) -> Self { Self { sessions: HashMap::new(), 
conversations: HashMap::new(), db_pool } }
    fn broadcast(&self, _conv_id: &Uuid, msg: &str, skip_id: Option<Uuid>) {
        for (user_id, session) in &self.sessions {
            if skip_id.map_or(true, |id| *user_id != id) {
                session.do_send(WsMessage(msg.to_owned()));
            }
        }
    }
}
impl Actor for ChatServer { type Context = Context<Self>; }

impl Handler<ClientMessage> for ChatServer {
    type Result = ();
    fn handle(&mut self, msg: ClientMessage, ctx: &mut Context<Self>) {
        log::info!("Received message: '{}' from user {}", msg.content, 
msg.sender_id);
        let db_pool = self.db_pool.clone();

        // Spawn a future to insert the message into the database
        let fut = async move {
            let insert_result = sqlx::query!(
                "INSERT INTO messages (conversation_id, sender_id, content) VALUES 
($1, $2, $3)",
                msg.conversation_id,
                msg.sender_id,
                msg.content
            )
            .execute(&db_pool)
            .await;

            match insert_result {
                Ok(_) => {
                    log::info!("Message saved to DB successfully.");
                    // Return the original message to broadcast it
                    Some(msg)
                }
                Err(e) => {
                    log::error!("Failed to save message to DB: {}", e);
                    // Return None if saving failed
                    None
                }
            }
        };

        // After the future completes, broadcast the message if it was saved
        fut.into_actor(self).then(|res, act, _| {
            if let Some(saved_msg) = res {
                let response = json!({"event": "new_message", "data": saved_msg});
                act.broadcast(&saved_msg.conversation_id, &response.to_string(), 
None);
            }
            fut::ready(())
        }).wait(ctx);
    }
}

// Other handlers remain the same...
impl Handler<Connect> for ChatServer {
    type Result = ();
    fn handle(&mut self, msg: Connect, ctx: &mut Context<Self>) {
        self.sessions.insert(msg.user_id, msg.addr);
        let db_pool = self.db_pool.clone();
        let fut = async move { sqlx::query!("UPDATE users SET online = TRUE WHERE 
id = $1", msg.user_id).execute(&db_pool).await };
        fut.into_actor(self).map(|_, _, _| {}).wait(ctx);
        let event = json!({"event": "user_online", "data": {"user_id": 
msg.user_id.to_string()}});
        self.broadcast(&Uuid::nil(), &event.to_string(), Some(msg.user_id));
    }
}
impl Handler<Disconnect> for ChatServer {
    type Result = ();
    fn handle(&mut self, msg: Disconnect, ctx: &mut Context<Self>) {
        self.sessions.remove(&msg.user_id);
        let db_pool = self.db_pool.clone();
        let fut = async move { sqlx::query!("UPDATE users SET online = FALSE, 
last_seen = NOW() WHERE id = $1", msg.user_id).execute(&db_pool).await };
        fut.into_actor(self).map(|_, _, _| {}).wait(ctx);
        let event = json!({"event": "user_offline", "data": {"user_id": 
msg.user_id.to_string()}});
        self.broadcast(&Uuid::nil(), &event.to_string(), None);
    }
}
impl Handler<Typing> for ChatServer {
    type Result = ();
    fn handle(&mut self, msg: Typing, _: &mut Context<Self>) {
        let response = json!({"event": "user_typing", "data": msg});
        self.broadcast(&msg.conversation_id, &response.to_string(), 
Some(msg.sender_id));
    }
}
