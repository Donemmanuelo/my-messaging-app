use crate::{models::Claims, utils::jwt::create_jwt};
use actix_web::{web, HttpMessage, HttpRequest, HttpResponse, Responder};
use sqlx::{types::Uuid, PgPool};

#[derive(Debug, sqlx::Type, PartialEq)]
#[sqlx(type_name = "qr_session_status", rename_all = "lowercase")]
enum QrSessionStatus { Pending, Scanned, Authenticated, }

pub async fn new_qr_session(pool: web::Data<PgPool>) -> impl Responder {
    match sqlx::query!("INSERT INTO qr_sessions (status) VALUES ('pending') RETURNING session_id").fetch_one(pool.get_ref()).await {
        Ok(r) => HttpResponse::Ok().json(serde_json::json!({ "session_id": r.session_id.to_string() })),
        Err(e) => { log::error!("New QR session failed: {}", e); HttpResponse::InternalServerError().finish() }
    }
}
pub async fn scan_qr_session(pool: web::Data<PgPool>, req: HttpRequest, path: web::Path<Uuid>) -> impl Responder {
    let user_id = Uuid::parse_str(&req.extensions().get::<Claims>().unwrap().sub).unwrap();
    let new_jwt = create_jwt(&user_id.to_string()).unwrap();
    match sqlx::query!("UPDATE qr_sessions SET status = 'scanned', user_id = $1, jwt = $2 WHERE session_id = $3", user_id, new_jwt, 
path.into_inner()).execute(pool.get_ref()).await {
        Ok(r) if r.rows_affected() > 0 => HttpResponse::Ok().finish(),
        Ok(_) => HttpResponse::NotFound().finish(),
        Err(e) => { log::error!("Scan QR failed: {}", e); HttpResponse::InternalServerError().finish() }
    }
}
pub async fn poll_qr_session(pool: web::Data<PgPool>, path: web::Path<Uuid>) -> impl Responder {
    let query_res = sqlx::query!(r#"SELECT status as "status: QrSessionStatus", jwt FROM qr_sessions WHERE session_id = $1"#, 
path.into_inner()).fetch_optional(pool.get_ref()).await;
    match query_res {
        Ok(Some(record)) => {
            // THE DEFINITIVE FIX: record.status is NOT an Option. We match on its variants directly.
            match record.status {
                QrSessionStatus::Scanned | QrSessionStatus::Authenticated => {
                    HttpResponse::Ok().json(serde_json::json!({ "token": record.jwt }))
                }
                QrSessionStatus::Pending => {
                    HttpResponse::Ok().json(serde_json::json!({ "status": "pending" }))
                }
            }
        }
        Ok(None) => HttpResponse::NotFound().finish(),
        Err(e) => { log::error!("Poll QR failed: {}", e); HttpResponse::InternalServerError().finish() }
    }
}
pub fn config(cfg: &mut web::ServiceConfig) {
    cfg.service(web::resource("/auth/qr/new").route(web::get().to(new_qr_session)))
       .service(web::resource("/auth/qr/scan/{session_id}").route(web::post().to(scan_qr_session)))
       .service(web::resource("/auth/qr/poll/{session_id}").route(web::get().to(poll_qr_session)));
}
