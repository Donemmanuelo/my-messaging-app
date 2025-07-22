use actix_web::{web, HttpResponse, Responder};
use aws_sdk_s3::{presigning::PresigningConfig, Client};
use std::time::Duration;
pub async fn get_upload_url(s3_client: web::Data<Client>) -> impl Responder {
    let bucket_name = std::env::var("S3_BUCKET_NAME").expect("S3_BUCKET_NAME must be set");
    let object_key = format!("uploads/{}.jpg", uuid::Uuid::new_v4());
    match 
s3_client.put_object().bucket(bucket_name).key(object_key.clone()).presigned(PresigningConfig::expires_in(Duration::from_secs(300)).unwrap()).await {
        Ok(p) => HttpResponse::Ok().json(serde_json::json!({"url": p.uri().to_string(), "key": object_key})),
        Err(e) => { log::error!("S3 presign failed: {:?}", e); HttpResponse::InternalServerError().finish() }
    }
}
pub fn config(cfg: &mut web::ServiceConfig) { cfg.service(web::resource("/media/upload-url").route(web::post().to(get_upload_url))); }
