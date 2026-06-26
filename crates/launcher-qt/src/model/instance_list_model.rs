#[derive(Debug, Clone, Default)]
pub struct InstanceListModelItem {
    pub id: String,
    pub title: String,
    pub subtitle: String,
    pub tag: String,
    pub icon_name: String,
    pub selected: bool,
    pub can_update: bool,
}

#[derive(Debug, Clone, Default)]
pub struct InstanceListModel(pub Vec<InstanceListModelItem>);

impl InstanceListModel {
    pub fn from_json(text: &str) -> Self {
        let Ok(value) = serde_json::from_str::<serde_json::Value>(text) else { return Self::default(); };
        let items = value.get("instances")
            .and_then(|instances| instances.as_array())
            .map(|instances| instances.iter().map(|item| InstanceListModelItem {
                id: item.get("id").and_then(|v| v.as_str()).unwrap_or_default().to_string(),
                title: item.get("title").and_then(|v| v.as_str()).unwrap_or_default().to_string(),
                subtitle: item.get("subtitle").and_then(|v| v.as_str()).unwrap_or_default().to_string(),
                tag: item.get("tag").and_then(|v| v.as_str()).unwrap_or_default().to_string(),
                icon_name: item.get("iconName").and_then(|v| v.as_str()).unwrap_or("grass").to_string(),
                selected: item.get("selected").and_then(|v| v.as_bool()).unwrap_or(false),
                can_update: item.get("canUpdate").and_then(|v| v.as_bool()).unwrap_or(false),
            }).collect::<Vec<_>>())
            .unwrap_or_default();
        Self(items)
    }
}
