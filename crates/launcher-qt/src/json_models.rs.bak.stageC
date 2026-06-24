use launcher_core::AuthAccount;

pub(crate) fn accounts_public_json(accounts: &[AuthAccount]) -> String {
    let values = accounts
        .iter()
        .map(|account| {
            serde_json::json!({
                "username": account.username,
                "uuid": account.uuid,
                "kind": account.kind,
                "displayKind": display_account_kind(&account.kind),
                "serverUrl": account.server_url,
                "avatarUrl": avatar_url_for_account(account),
                "note": account.note,
                "identifier": launcher_core::account_identifier(account),
                "selected": launcher_core::selected_account()
                    .ok()
                    .flatten()
                    .map(|selected| launcher_core::account_identifier(&selected) == launcher_core::account_identifier(account))
                    .unwrap_or(false),
            })
        })
        .collect::<Vec<_>>();

    serde_json::json!({
        "accounts": values
    })
    .to_string()
}

pub(crate) fn display_account_kind(kind: &str) -> String {
    match kind {
        "offline" => "离线账户".to_string(),
        "microsoft" => "Microsoft".to_string(),
        "yggdrasil" => "第三方服务器".to_string(),
        other => other.to_string(),
    }
}

pub(crate) fn avatar_url_for_account(account: &AuthAccount) -> String {
    launcher_core::account_avatar_url(account, 96)
        .ok()
        .flatten()
        .unwrap_or_default()
}
