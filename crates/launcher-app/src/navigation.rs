#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PageKey { Main, Account, Download, InstanceList, InstanceManage, Settings, Java, Placeholder(String) }

#[derive(Debug, Clone)]
pub struct PageEntry { pub key: PageKey, pub title: String }

#[derive(Debug, Default)]
pub struct NavigationState { stack: Vec<PageEntry> }

impl NavigationState {
    pub fn push(&mut self, entry: PageEntry) { self.stack.push(entry); }
    pub fn pop(&mut self) -> Option<PageEntry> { self.stack.pop() }
    pub fn current(&self) -> Option<&PageEntry> { self.stack.last() }
    pub fn clear(&mut self) { self.stack.clear(); }
}
