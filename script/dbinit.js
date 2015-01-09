// use db bookkeeping
db = new Mongo().getDB("exasteel");
// create users collection
admin = { username: "admin", password: "adpexzg3FUZAk", last_login: new Date(), role: "admin", firstname: "", lastname: "" };
// create default admin user (password admin)
db.users.insert(admin);
///////////////////////////////////////////////
// Other collections with one sample obj each
///////////////////////////////////////////////
// Virtual Data Centers
sample_vdc = {
  display_name: 'vDC Site 1',
  emoc_endpoint: 'https://hostname:port/uri/',
  emoc_username: 'username',
  emoc_password: 'password',
  description: 'My first vDC in site 1 (autofilled if possible)',
  tags: '',
  ignored_accounts: '',
};
// let's insert those sample records and create the collections!
db.vdcs.insert(sample_vdc);
// addtional collections for:
// - accounts?
// - perf data as a cache?