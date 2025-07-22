use crate::{models::{AuthResponse, SendOtpRequest, User, VerifyOtpRequest}, utils::jwt::create_jwt};
use actix_web::{web, HttpResponse, Responder};
use bcrypt::{hash, verify, DEFAULT_COST};
use rand::{thread_rng, Rng};
use serde_json::json;
use sqlx::PgPool;
pub async fn send_otp(pool: web::Data<PgPool>, req: web::Json<SendOtpRequest>) -> impl Responder {
    let otp = format!("{:06}", thread_rng().gen_range(0..=999_999));
    let otp_hash = match hash(&otp, DEFAULT_COST) { Ok(h) => h, Err(_) => return HttpResponse::InternalServerError().finish() };
    match sqlx::query!("INSERT INTO temp_otps (phone_number, otp_hash, created_at) VALUES ($1, $2, NOW()) ON CONFLICT (phone_number) DO UPDATE SET otp_hash = $2, created_at = NOW()", req.phone_number, otp_hash)
        .execute(pool.get_ref()).await {
        Ok(_) => { log::info!("OTP for {}: {}", req.phone_number, otp); HttpResponse::Ok().json(json!({"status": "success"})) },
        Err(e) => { log::error!("Failed to save OTP: {}", e); HttpResponse::InternalServerError().finish() }
    }
}
pub async fn verify_otp(pool: web::Data<PgPool>, req: web::Json<VerifyOtpRequest>) -> impl Responder {
    match sqlx::query!("SELECT otp_hash FROM temp_otps WHERE phone_number = $1", req.phone_number).fetch_optional(pool.get_ref()).await {
        Ok(Some(record)) => if verify(&req.otp, &record.otp_hash).unwrap_or(false) {
            // THE FIX IS HERE: Added 'name' to the SELECT statement
            let user_res = sqlx::query_as!(User, "SELECT id, phone_number, name FROM users WHERE phone_number = $1", req.phone_number).fetch_optional(pool.get_ref()).await;
            let user_id = match user_res {
                Ok(Some(user)) => user.id,
                Ok(None) => sqlx::query!("INSERT INTO users (phone_number) VALUES ($1) RETURNING id", req.phone_number).fetch_one(pool.get_ref()).await.unwrap().id,
                Err(_) => return HttpResponse::InternalServerError().finish(),
            };
            sqlx::query!("DELETE FROM temp_otps WHERE phone_number = $1", req.phone_number).execute(pool.get_ref()).await.ok();
            let token = create_jwt(&user_id.to_string()).unwrap();
            HttpResponse::Ok().json(AuthResponse { token, user_id: user_id.to_string() })
        } else { HttpResponse::Unauthorized().json(json!({"message": "Invalid OTP"})) },
        _ => HttpResponse::NotFound().json(json!({"message": "OTP not found or expired"}))
    }
}
pub fn config(cfg: &mut web::ServiceConfig) { cfg.service(web::resource("/auth/send-otp").route(web::post().to(send_otp))).service(web::resource("/auth/verify-otp").route(web::post().to(verify_otp))); }