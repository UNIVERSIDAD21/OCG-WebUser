console.log("inicio script");
const admin = require("firebase-admin");

const keyPath = "C:/Users/HumanBionics/Downloads/ocg-admin-key.json";
console.log("cargando key:", keyPath);

const key = require(keyPath);
console.log("project_id key:", key.project_id);

admin.initializeApp({
credential: admin.credential.cert(key),
});

async function run() {
const uid = "T3oePjOMwKRiR5yqDRvT4dGU7p93";
console.log("set claims para uid:", uid);

await admin.auth().setCustomUserClaims(uid, { role: "admin", admin: true });
console.log("claims seteados");

const user = await admin.auth().getUser(uid);
console.log("claims actuales:", user.customClaims);

process.exit(0);
}

run().catch((e) => {
console.error("ERROR RUN:", e);
process.exit(1);
});