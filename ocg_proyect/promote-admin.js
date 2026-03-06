const admin = require("firebase-admin");
const path = "C:/Users/HumanBionics/Downloads/ocg-admin-key.json";

admin.initializeApp({
credential: admin.credential.cert(require(path)),
});

async function run() {
const uid = "T3oePjOMwKRiR5yqDRvT4dGU7p93";
const email = "admin@ocg.com";

const user = await admin.auth().getUser(uid);
const claims = user.customClaims || {};

await admin.auth().setCustomUserClaims(uid, {
...claims,
role: "admin",
admin: true,
});

await admin.firestore().collection("admins").doc(uid).set(
{
uid,
email,
role: "admin",
updatedAt: admin.firestore.FieldValue.serverTimestamp(),
},
{ merge: true }
);

console.log("OK: usuario promovido a admin:", uid, email);
}

run().catch((e) => {
console.error("ERROR:", e);
process.exit(1);
});