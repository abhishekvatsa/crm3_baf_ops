import { initializeApp } from "firebase/app";
import { getAuth, signInWithEmailAndPassword } from "firebase/auth";
import {
  getFirestore,
  doc,
  updateDoc,
  increment,
} from "firebase/firestore";

const firebaseConfig = {
  apiKey: "AIzaSyCe_Bz7zowdJhWINJIRI9NyfpGCEtORzM8",
  authDomain: "crm3-baf-ops-b8638.firebaseapp.com",
  projectId: "crm3-baf-ops-b8638",
  storageBucket: "crm3-baf-ops-b8638.firebasestorage.app",
  messagingSenderId: "894346496105",
  appId: "1:894346496105:web:b7a8cff97a3a90a0e63af8",
};

const executionId = "e3bdc34a-19b0-4d9f-a4d2-64161a18a8b7";

const email = process.env.BAF_TEST_EMAIL;
const password = process.env.BAF_TEST_PASSWORD;

if (!email || !password) {
  console.error("Missing BAF_TEST_EMAIL or BAF_TEST_PASSWORD environment variable.");
  process.exit(2);
}

const app = initializeApp(firebaseConfig);
const auth = getAuth(app);
const db = getFirestore(app);

try {
  const credential = await signInWithEmailAndPassword(auth, email, password);
  const user = credential.user;

  console.log("Signed in as:", user.uid);
  console.log("Trying forbidden direct completion write...");

  await updateDoc(doc(db, "job_executions", executionId), {
    isCompleted: true,
    completedAt: new Date().toISOString(),
    completedByUid: user.uid,
    completedByName: "Direct Client Denial Test",
    updatedAt: new Date().toISOString(),
    version: increment(1),
  });

  console.error("❌ UNEXPECTED: direct client completion write succeeded.");
  process.exit(1);
} catch (error) {
  console.log("Write failed.");
  console.log("Code:", error.code);
  console.log("Message:", error.message);

  if (
    error.code === "permission-denied" ||
    String(error.message).includes("PERMISSION_DENIED")
  ) {
    console.log("✅ PASS: direct client completion is denied by Firestore rules.");
    process.exit(0);
  }

  console.error("❌ FAILED FOR A DIFFERENT REASON.");
  process.exit(2);
}