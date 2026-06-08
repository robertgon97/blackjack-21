/** @type {import('tailwindcss').Config} */
module.exports = {
  // Archivos donde Tailwind busca clases usadas (para no generar CSS de más).
  content: ["./index.html", "./js/**/*.js"],

  // Desactivamos el "preflight" (reset agresivo de Tailwind): este proyecto ya
  // tiene su propio reset (`* { margin:0; padding:0; box-sizing }`) y un sistema
  // de 4 temas con variables CSS. Sin esto, Tailwind pisaría botones, listas,
  // títulos e inputs ya estilizados. Ver CLAUDE.md.
  corePlugins: {
    preflight: false,
  },

  theme: {
    extend: {
      // Colores enlazados a las variables CSS de los temas: así utilidades como
      // `bg-acento` o `text-acento` cambian solas con el tema activo (verde/azul/
      // rojo/oscuro). Es la forma de que Tailwind respete el sistema de temas.
      colors: {
        acento: "var(--acento)",
        tapete: "var(--tapete1)",
        "tapete-hondo": "var(--tapete2)",
        caja: "var(--caja-bg)",
        texto: "var(--texto)",
      },
    },
  },
  plugins: [],
};
