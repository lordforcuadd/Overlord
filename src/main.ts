import { createApp } from "vue";
import { createPinia } from "pinia"; // Importamos Pinia
import "./style.css";
import App from "./App.vue";

const app = createApp(App);
const pinia = createPinia(); // Creamos la instancia

app.use(pinia);
app.mount("#app");
