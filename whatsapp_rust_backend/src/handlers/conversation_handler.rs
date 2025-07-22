use crate::models::{Claims, ChatMessage, ConversationDetails};
use actix_web::{web, HttpMessage, HttpRequest, HttpResponse, Responder};
use sqlx::{types::Uuid, PgPool};

pub async fn get_conversations(pool: web::Data<PgPool>, req: HttpRequest) -> impl 
Responder {
    let user_id = 
Uuid::parse_str(&req.extensions().get::<Claims>().unwrap().sub).unwrap();
    let query_result = sqlx::query_as!(
        ConversationDetails,
        r#"
        WITH LastMessages AS (
            SELECT conversation_id, content, created_at, ROW_NUMBER() 
OVER(PARTITION BY conversation_id ORDER BY created_at DESC) as rn
            FROM messages
        )
        SELECT c.id as "conversation_id!", c.is_group, c.group_name, 
other_p.user_id as "other_user_id?", other_u.name as "other_user_name?", 
lm.content as "last_message?", lm.created_at as "last_message_at?"
        FROM conversation_participants cp
        JOIN conversations c ON cp.conversation_id = c.id
        LEFT JOIN conversation_participants other_p ON c.id = 
other_p.conversation_id AND other_p.user_id != $1
        LEFT JOIN users other_u ON other_p.user_id = other_u.id
        LEFT JOIN LastMessages lm ON c.id = lm.conversation_id AND lm.rn = 1
        WHERE cp.user_id = $1
        ORDER BY lm.created_at DESC NULLS LAST;
        "#,
        user_id
    ).fetch_all(pool.get_ref()).await;
    match query_result {
        Ok(convos) => HttpResponse::Ok().json(convos),
        Err(e) => { log::error!("Failed to fetch conversations: {}", e); 
HttpResponse::InternalServerError().finish() }
    }
}

// --- ADD NEW HANDLER FOR MESSAGE HISTORY ---
pub async fn get_message_history(pool: web::Data<PgPool>, path: web::Path<Uuid>) 
-> impl Responder {
    let conversation_id = path.into_inner();
    let query_result = sqlx::query_as!(
        ChatMessage,
        "SELECT id, conversation_id, sender_id, content, created_at FROM messages 
WHERE conversation_id = $1 ORDER BY created_at ASC",
        conversation_id
    )
    .fetch_all(pool.get_ref())
    .await;

    match query_result {
        Ok(messages) => HttpResponse::Ok().json(messages),
        Err(e) => {
            log::error!("Failed to fetch message history: {}", e);
            HttpResponse::InternalServerError().finish()
        }
    }
}

pub fn config(cfg: &mut web::ServiceConfig) {
    
cfg.service(web::resource("/conversations").route(web::get().to(get_conversations)))
       
.service(web::resource("/conversations/{id}/messages").route(web::get().to(get_message_history)));
}
