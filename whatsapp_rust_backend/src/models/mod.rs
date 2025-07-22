use chrono::{DateTime, Utc};
use serde::{Deserialize, Serialize};
use sqlx::FromRow;
use uuid::Uuid;

#[derive(Serialize, FromRow, Debug)]
pub struct User { pub id: Uuid, pub phone_number: String, pub name: Option<String> 
}

#[derive(Serialize, FromRow, Debug)]
pub struct ConversationDetails {
    pub conversation_id: Uuid,
    pub is_group: bool,
    pub group_name: Option<String>,
    pub other_user_id: Option<Uuid>,
    pub other_user_name: Option<String>,
    pub last_message: Option<String>,
    pub last_message_at: Option<DateTime<Utc>>,
}

#[derive(Serialize, FromRow, Debug)]
#[sqlx(rename_all = "lowercase")]
pub struct ChatMessage {
    pub id: Uuid,
    pub conversation_id: Uuid,
    pub sender_id: Uuid,
    pub content: String,
    // We will handle message_type and status later
    pub created_at: DateTime<Utc>,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Claims { pub sub: String, pub exp: usize }
#[derive(Deserialize)]
pub struct SendOtpRequest { pub phone_number: String }
#[derive(Deserialize)]
pub struct VerifyOtpRequest { pub phone_number: String, pub otp: String }
#[derive(Serialize)]
pub struct AuthResponse { pub token: String, pub user_id: String }
