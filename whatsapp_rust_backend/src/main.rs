use actix::Actor;
use actix_cors::Cors;
use actix_web::{http, middleware::Logger, web, App, HttpServer};
use dotenv::dotenv;
use sqlx::postgres::PgPoolOptions;
use std::env;

mod actors;
mod handlers;
mod models;
mod utils;

use actors::server::ChatServer;
use handlers::{auth_handler, conversation_handler, key_handler, media_handler, 
qr_auth_handler, user_handler, ws_handler};
use utils::auth_middleware::JwtAuth; // <-- Import the middleware

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    dotenv().ok();
    env_logger::init_from_env(env_logger::Env::new().default_filter_or("info"));

    let host = env::var("HOST").expect("HOST must be set");
    let port = env::var("PORT").expect("PORT must be 
set").parse::<u16>().unwrap();
    let db_url = env::var("DATABASE_URL").expect("DATABASE_URL must be set");

    log::info!("Starting server at http://{}:{}", host, port);

    let aws_config = aws_config::load_from_env().await;
    let s3_client = aws_sdk_s3::Client::new(&aws_config);
    let db_pool = 
PgPoolOptions::new().max_connections(10).connect(&db_url).await.expect("DB pool 
failed");
    
    sqlx::migrate!("./migrations").run(&db_pool).await.expect("Migrations 
failed");
    log::info!("Database migrations completed.");

    let chat_server = ChatServer::new(db_pool.clone()).start();

    HttpServer::new(move || {
        let cors = Cors::default()
            .allow_any_origin()
            .allowed_methods(vec!["GET", "POST", "PUT", "DELETE"])
            .allowed_headers(vec![http::header::AUTHORIZATION, 
http::header::ACCEPT, http::header::CONTENT_TYPE])
            .max_age(3600);

        App::new()
            .app_data(web::Data::new(db_pool.clone()))
            .app_data(web::Data::new(chat_server.clone()))
            .app_data(web::Data::new(s3_client.clone()))
            .wrap(cors)
            .wrap(Logger::default())
            .service(
                web::scope("/api")
                    // Public routes that DON'T need the middleware
                    .configure(auth_handler::config)
                    .configure(qr_auth_handler::config)

                    // Protected routes that DO need the middleware
                    .service(
                        web::scope("") // An empty scope to apply the middleware
                            .wrap(JwtAuth) // <-- APPLY THE MIDDLEWARE HERE
                            .configure(conversation_handler::config)
                            // The following handlers are also now protected
                            .configure(key_handler::config)
                            .configure(user_handler::config)
                            .configure(media_handler::config)
                    )
            )
            .route("/ws", web::get().to(ws_handler::ws_connect))
    })
    .bind((host, port))?
    .run()
    .await
}
