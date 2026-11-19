<?php
/**
 * Plugin Name:       Salon Manager – App Login
 * Description:       Lets the Hallak Admin iPhone app open any salon dashboard signed in as you: the app asks for a one-time link (valid 60 seconds, usable once), and the in-app page opens the dashboard with a normal WordPress login.
 * Version:           1.0.0
 * Requires at least: 6.2
 * Requires PHP:      7.4
 * Author:            Hallak
 * Text Domain:       salon-manager
 *
 * Endpoint: POST /wp-json/hallak/v1/admin/salons/{id}/web-login   body: {"tab": ""} (optional)
 * Answer:   {"url": "https://…/?hallak_app_login=…", "expires_in": 60, "target": "https://…/salon/slug/", "generated_at": "…", "tz": "Asia/Beirut"}
 *
 * Safety:
 * - Only administrators (manage_options + sm_manage_all_salons), only over HTTPS.
 * - Only when the request was made with an Application Password (the app), never with a browser cookie.
 * - The link works once, for 60 seconds; only a hash of it is stored.
 * - Every sign-in is written to the salon's activity log ("Opened from the iPhone app").
 */

if ( ! defined( 'ABSPATH' ) ) {
	exit;
}

final class SM_App_Login {

	const TTL    = 60;
	const PARAM  = 'hallak_app_login';
	const PREFIX = 'hallak_wl_';

	public static function init() {
		add_action( 'rest_api_init', array( __CLASS__, 'routes' ) );
		// Early, before the salon dashboard decides the visitor is not logged in.
		add_action( 'init', array( __CLASS__, 'consume' ), 1 );
	}

	/* ------------------------------------------------------------ REST */

	public static function routes() {
		register_rest_route(
			'hallak/v1',
			'/admin/salons/(?P<id>\d+)/web-login',
			array(
				'methods'             => WP_REST_Server::CREATABLE,
				'callback'            => array( __CLASS__, 'create' ),
				'permission_callback' => array( __CLASS__, 'allowed' ),
				'args'                => array(
					'id'  => array(
						'validate_callback' => function ( $v ) {
							return is_numeric( $v ) && (int) $v > 0;
						},
					),
					'tab' => array(
						'type'              => 'string',
						'required'          => false,
						'sanitize_callback' => 'sanitize_key',
					),
				),
			)
		);
	}

	/** Administrators only, HTTPS only, and only with an Application Password. */
	public static function allowed( WP_REST_Request $request ) {
		if ( ! is_ssl() ) {
			return new WP_Error( 'smapi_https', __( 'The site must use https.', 'salon-manager' ), array( 'status' => 403 ) );
		}
		if ( ! is_user_logged_in() ) {
			return new WP_Error( 'smapi_login', __( 'Not logged in.', 'salon-manager' ), array( 'status' => 401 ) );
		}
		if ( ! current_user_can( 'manage_options' ) || ! current_user_can( 'sm_manage_all_salons' ) ) {
			return new WP_Error( 'smapi_forbidden', __( 'This account is not an administrator.', 'salon-manager' ), array( 'status' => 403 ) );
		}
		// A sign-in link may only be made by the app (Application Password), not by a page in a browser.
		if ( ! function_exists( 'rest_get_authenticated_app_password' ) || ! rest_get_authenticated_app_password() ) {
			return new WP_Error( 'smapi_app_only', __( 'Only the Hallak Admin app can ask for this link.', 'salon-manager' ), array( 'status' => 403 ) );
		}
		return true;
	}

	public static function create( WP_REST_Request $request ) {
		if ( ! class_exists( 'SM_Salons' ) || ! class_exists( 'SM_Dashboard' ) ) {
			return new WP_Error( 'smapi_no_core', __( 'Salon Manager Core is not active.', 'salon-manager' ), array( 'status' => 404 ) );
		}

		$salon_id = (int) $request['id'];
		$salon    = SM_Salons::get( $salon_id );
		if ( ! $salon ) {
			return new WP_Error( 'smapi_not_found', __( 'Salon not found.', 'salon-manager' ), array( 'status' => 404 ) );
		}

		$target = SM_Dashboard::url( $salon_id, (string) $request->get_param( 'tab' ) );
		if ( ! $target ) {
			return new WP_Error( 'smapi_not_found', __( 'Salon not found.', 'salon-manager' ), array( 'status' => 404 ) );
		}

		$token = wp_generate_password( 48, false, false );
		set_transient(
			self::PREFIX . hash( 'sha256', $token ),
			array(
				'user_id'  => get_current_user_id(),
				'salon_id' => $salon_id,
				'target'   => $target,
			),
			self::TTL
		);

		$now = new DateTime( 'now', new DateTimeZone( 'Asia/Beirut' ) );

		return rest_ensure_response(
			array(
				'url'          => add_query_arg( self::PARAM, rawurlencode( $token ), home_url( '/' ) ),
				'expires_in'   => self::TTL,
				'target'       => $target,
				'generated_at' => $now->format( 'Y-m-d H:i' ),
				'tz'           => 'Asia/Beirut',
			)
		);
	}

	/* ------------------------------------------------- Opening the link */

	public static function consume() {
		if ( empty( $_GET[ self::PARAM ] ) ) {
			return;
		}

		nocache_headers();
		header( 'Referrer-Policy: no-referrer' );

		$token = sanitize_text_field( wp_unslash( $_GET[ self::PARAM ] ) );
		$key   = self::PREFIX . hash( 'sha256', $token );
		$data  = get_transient( $key );
		delete_transient( $key ); // Usable once, even when something below fails.

		if ( ! is_ssl() || ! is_array( $data ) || empty( $data['user_id'] ) || empty( $data['target'] ) ) {
			self::fail();
		}

		$user = get_userdata( (int) $data['user_id'] );
		if ( ! $user || ! user_can( $user, 'manage_options' ) || ! user_can( $user, 'sm_manage_all_salons' ) ) {
			self::fail();
		}

		// Only send the visitor to a page of this site.
		$target = wp_validate_redirect( $data['target'], '' );
		if ( '' === $target ) {
			self::fail();
		}

		// No 'wp_login' action on purpose: two-factor plugins hook it and would stop this
		// sign-in. The app already proved who you are with the Application Password.
		wp_set_current_user( $user->ID );
		wp_set_auth_cookie( $user->ID, false, true );

		if ( class_exists( 'SM_Log' ) && ! empty( $data['salon_id'] ) ) {
			SM_Log::add( (int) $data['salon_id'], 'app_dashboard_open', __( 'Dashboard opened from the iPhone app', 'salon-manager' ), 'salon', (int) $data['salon_id'] );
		}

		wp_safe_redirect( $target );
		exit;
	}

	private static function fail() {
		wp_die(
			esc_html__( 'This link has expired or was already used. Open the dashboard again from the Hallak Admin app.', 'salon-manager' ),
			esc_html__( 'Link expired', 'salon-manager' ),
			array( 'response' => 403 )
		);
	}
}

SM_App_Login::init();
