use crate::{actors::session::WebSocketSession, utils::jwt::decode_jwt, actors::server::ChatServer};
use actix::Addr;
use actix_web::{web, Error, HttpRequest, HttpResponse};
use actix_web_actors::ws;
use uuid::Uuid;
pub async fn ws_connect(req: HttpRequest, stream: web::Payload, srv: web::Data<Addr<ChatServer>>) -> Result<HttpResponse, Error> {
    let token = req.query_string().split('&').find(|s| s.starts_with("token=")).map(|s| s.split('=').nth(1).unwrap_or("")).unwrap_or("");
    match decode_jwt(token) {
        Ok(claims) => ws::start(WebSocketSession::new(Uuid::parse_str(&claims.sub).unwrap(), srv.get_ref().clone()),&req,stream),
        Err(_) => Ok(HttpResponse::Unauthorized().finish()),
    }
}
