/* Dos Coronas — comportamiento de la web: pestañas de clases, galería, menú, aparición al hacer scroll y datos de la descarga. */
(function () {
  "use strict";

  // ------------------------------------------------------------------ datos del juego (sacados de compartido/datos/*.xml)
  var CLASES = [
    { id: "guerrero", nombre: "Guerrero", rol: "Tanque y daño cuerpo a cuerpo",
      texto: "Aguanta el frente, parte a los enemigos en área y se lanza contra las líneas. El primero en entrar y el último en caer.",
      stats: { hp: 160, mp: 50, atq: 15, mag: 4, def: 9 }, sprites: ["clase_guerrero_albor", "clase_guerrero_umbra"],
      poderes: [["Golpe", "Un golpe firme con el arma.", "10 maná · 1,5 s"], ["Tajo", "Golpea a todos los enemigos cercanos.", "14 maná · 7 s"], ["Grito de guerra", "Aumenta el ataque de los aliados cercanos.", "18 maná · 16 s"], ["Carga", "Te lanzas al objetivo y lo aturdes un instante.", "12 maná · 11 s"], ["Pantera asesina", "Lanzas una pantera de fuego que embiste al enemigo y lo prende.", "22 maná · 9 s"], ["Furia", "Tu ataque crece mucho durante un rato.", "28 maná · 32 s"], ["Golpe terrestre", "Golpeas el suelo: daña y aturde a los enemigos de la zona.", "30 maná · 12 s"], ["Salto de impacto", "Saltas hasta un punto y lo aplastas al caer: daña y ralentiza.", "28 maná · 14 s"], ["Estocada lineal", "Una estocada larga y certera que hace sangrar.", "20 maná · 6 s"], ["Ejecución", "Remata a su presa: daña mucho más a un enemigo con poca vida.", "40 maná · 22 s"]] },
    { id: "mago", nombre: "Mago", rol: "Daño mágico a distancia",
      texto: "Quema y hiela desde lejos. Frágil, y devastador si lo dejan lanzar. El mayor daño del juego, a cambio de una vida muy justa.",
      stats: { hp: 100, mp: 160, atq: 5, mag: 17, def: 3 }, sprites: ["clase_mago_albor", "clase_mago_umbra"],
      poderes: [["Misil arcano", "Un dardo de energía.", "8 maná · 2 s"], ["Bola de fuego", "Estalla al impactar.", "24 maná · 3 s"], ["Escudo arcano", "Absorbe parte del daño.", "50 maná · 15 s"], ["Ventisca", "Eliges una zona: una ventisca de cristales de hielo cae sobre ella, la daña y ralentiza.", "50 maná · 8 s"], ["Rayo de hielo", "Una lanza de hielo que ralentiza al objetivo.", "34 maná · 6 s"], ["Meteoro", "Una roca en llamas cae sobre la zona.", "45 maná · 22 s"], ["Rayo arcano", "Un haz de energía pura que atraviesa las defensas.", "42 maná · 9 s"], ["Lluvia de fuego", "Una lluvia de fuego cae sobre la zona.", "58 maná · 16 s"], ["Teletransporte", "Te desplazas al instante al punto elegido.", "30 maná · 14 s"], ["Torbellino arcano", "Un torbellino de energía que castiga la zona varias veces y ralentiza.", "75 maná · 26 s"]] },
    { id: "cazador", nombre: "Cazador", rol: "Daño físico a distancia",
      texto: "Dispara, coloca trampas y hace llover flechas sobre el campo. Rápido, preciso y difícil de alcanzar.",
      stats: { hp: 118, mp: 90, atq: 16, mag: 5, def: 5 }, sprites: ["clase_cazador_albor", "clase_cazador_umbra"],
      poderes: [["Disparo", "Una flecha rápida.", "6 maná · 1,05 s"], ["Lluvia de flechas", "Flechas sobre una zona.", "22 maná · 8 s"], ["Trampa", "Inmoviliza al primer enemigo que la pisa.", "16 maná · 14 s"], ["Tiro preciso", "Un disparo devastador.", "18 maná · 8 s"], ["Flecha envenenada", "Una flecha untada que envenena.", "16 maná · 7 s"], ["Paso ágil", "Corres mucho más rápido un momento.", "14 maná · 18 s"], ["Disparo múltiple", "Una andanada que alcanza también a los que rodean al objetivo.", "24 maná · 6 s"], ["Disparo explosivo", "Una flecha que estalla al impactar y prende a los cercanos.", "34 maná · 12 s"], ["Disparo helado", "Una flecha de hielo que ralentiza mucho al objetivo.", "26 maná · 9 s"], ["Marca del cazador", "Marcas a tu presa: recibe un 25% más de daño de cualquiera durante unos segundos.", "22 maná · 20 s"]] },
    { id: "clerigo", nombre: "Clérigo", rol: "Curación, apoyo y castigo",
      texto: "Cura y bendice a los suyos, y castiga con luz a quien se acerque. Sin un clérigo, ningún grupo aguanta una mazmorra.",
      stats: { hp: 128, mp: 155, atq: 5, mag: 11, def: 3 }, sprites: ["clase_clerigo_albor", "clase_clerigo_umbra"],
      poderes: [["Curación", "Restaura vida a un aliado o a ti.", "16 maná · 2,1 s"], ["Rayo bendito", "Un rayo bendito que hiere al enemigo. Se aprende al nivel 5.", "16 maná · 4 s"], ["Castigo", "Luz que hiere. El clérigo también ataca.", "10 maná · 1,35 s"], ["Consagración", "Daña enemigos y cura aliados a tu alrededor.", "28 maná · 10 s"], ["Luz sanadora", "Cura a todos los aliados cercanos.", "38 maná · 15 s"], ["Juicio divino", "Un haz de luz que hiere y aturde.", "34 maná · 16 s"], ["Escudo divino", "Un escudo de luz absorbe el daño de un aliado o el tuyo.", "45 maná · 18 s"], ["Cadena de sanación", "Cura a un aliado y la luz salta a otros dos cercanos.", "36 maná · 9 s"], ["Tormenta divina", "Una tormenta de luz castiga tres veces la zona y cura a tus aliados dentro.", "70 maná · 24 s"], ["Resurrección", "Devuelve a la vida a un aliado caído cerca de ti, con la mitad de su vida.", "100 maná · 90 s"]] },
    { id: "lancero", nombre: "Lancero", rol: "Daño físico con alcance", exclusiva: "albor",
      texto: "Combate con la lanza: alcance largo, estocadas, embestidas y una lluvia de lanzas. Golpea antes de que lleguen a él.",
      stats: { hp: 150, mp: 70, atq: 16, mag: 4, def: 8 }, sprites: ["clase_lancero_albor"],
      poderes: [["Estocada", "Una estocada larga con la lanza.", "9 maná · 1,3 s"], ["Barrido", "Barres con el asta a todos los enemigos cercanos y los frenas.", "16 maná · 8 s"], ["Muro de lanzas", "Levantas un muro de lanzas que absorbe parte del daño.", "22 maná · 18 s"], ["Embestida", "Cargas con la lanza por delante y aturdes un instante.", "14 maná · 11 s"], ["Jabalina", "Lanzas una jabalina a distancia que deja una herida.", "18 maná · 6 s"], ["Tormenta de lanzas", "Una lluvia de lanzas cae sobre la zona.", "40 maná · 22 s"], ["Fisura del lancero", "Clavas la lanza y abres una fisura que daña y frena a los de la zona.", "30 maná · 12 s"], ["Pulso terrestre", "Una onda de choque a tu alrededor daña y aturde.", "28 maná · 14 s"], ["Torbellino de lanzas", "Giras la lanza sin parar: golpeas cuatro veces a los que te rodean.", "45 maná · 20 s"], ["Juicio final", "Una lluvia de lanzas de luz cae tres veces sobre la zona.", "70 maná · 30 s"]] },
    { id: "nigromante", nombre: "Nigromante", rol: "Maná, maldiciones y esbirros", exclusiva: "umbra",
      texto: "Maldice, drena la vida y alza esqueletos y espectros que luchan a su lado. Nunca combate solo.",
      stats: { hp: 104, mp: 175, atq: 5, mag: 16, def: 3 }, sprites: ["clase_nigromante_umbra"],
      poderes: [["Calavera espectral", "Una calavera de fuego espectral vuela hasta el objetivo, lo hiere y a veces le drena la vida.", "7 maná · 2 s"], ["Manos de ultratumba", "Manos esqueléticas surgen del suelo, agarran y desgarran la zona.", "22 maná · 8 s"], ["Flor de maldición", "Una flor sombría brota bajo el objetivo: lo frena y lo debilita.", "20 maná · 12 s"], ["Portal sombrío", "Abres un portal de sombras del que salen dos esqueletos que luchan a tu lado un buen rato.", "38 maná · 20 s"], ["Torbellino de almas", "Un torbellino de almas envuelve al objetivo y le roba la vida.", "26 maná · 8 s"], ["Escudo de huesos", "Una esfera de huesos y almas te rodea y absorbe parte del daño.", "55 maná · 22 s"], ["Erupción necrótica", "Una erupción de energía necrótica brota del suelo y desgarra a todos los de la zona.", "40 maná · 14 s"], ["Guadaña de sombras", "Una guadaña de sombras gira a tu alrededor, daña y frena a los enemigos.", "38 maná · 12 s"], ["Cadenas condenadas", "Cadenas de almas atrapan la zona: dañan tres veces y frenan a los enemigos.", "65 maná · 24 s"], ["Lanza ósea", "Una lanza de hueso imbuida de almas atraviesa al objetivo con un daño enorme.", "80 maná · 30 s"]] }
  ];
  var MAXIMOS = { hp: 175, mp: 175, atq: 16, mag: 17, def: 9 };
  var NOMBRES_STAT = { hp: "Vida", mp: "Maná", atq: "Ataque", mag: "Magia", def: "Defensa" };

  function el(tag, clase, html) {
    var e = document.createElement(tag);
    if (clase) e.className = clase;
    if (html != null) e.innerHTML = html;
    return e;
  }

  // ------------------------------------------------------------------ clases
  var cont = document.getElementById("clases-contenido");
  if (cont) {
    var pestanas = document.getElementById("clases-pestanas");
    var actual = 0;
    function pintar(i) {
      actual = i;
      var c = CLASES[i];
      Array.prototype.forEach.call(pestanas.children, function (b, k) { b.setAttribute("aria-selected", k === i ? "true" : "false"); });
      var caja = el("div", "clase cristal");
      var imgs = c.sprites.map(function (s) { return '<img class="pixel" src="img/sprites/' + s + '.png" alt="' + c.nombre + '">'; }).join("");
      var pie = c.sprites.length > 1 ? "<small>Alba · Umbra</small>" : "<small>" + (c.exclusiva === "albor" ? "Exclusiva de Alba" : "Exclusiva de Umbra") + "</small>";
      caja.appendChild(el("div", "retrato", '<div><div class="' + (c.sprites.length > 1 ? "doble" : "") + '">' + imgs + "</div>" + pie + "</div>"));
      var barras = Object.keys(c.stats).map(function (k) {
        return '<div class="barra ' + k + '"><label><span>' + NOMBRES_STAT[k] + "</span><b>" + c.stats[k] + '</b></label><div class="pista"><i data-w="' + Math.round(c.stats[k] / MAXIMOS[k] * 100) + '"></i></div></div>';
      }).join("");
      var poderes = c.poderes.map(function (p, k) {
        return '<div class="poder"><div class="tecla">' + (k + 1) + "</div><div><b>" + p[0] + "</b><span>" + p[1] + "</span><em>" + p[2] + "</em></div></div>";
      }).join("");
      var marca = c.exclusiva ? '<span class="rol exclusiva ' + (c.exclusiva === "albor" ? "albor" : "") + '">' + (c.exclusiva === "albor" ? "Solo Alba" : "Solo Umbra") + "</span>" : "";
      caja.appendChild(el("div", "cuerpo", '<span class="rol">' + c.rol + "</span>" + marca + "<h3>" + c.nombre + "</h3><p>" + c.texto + '</p><div class="barras">' + barras + '</div><h4 style="font-size:.9rem;letter-spacing:.15em;text-transform:uppercase;color:#7f93d6">Los diez poderes (teclas 1 a 6, Z, X, V y F)</h4><div class="poderes">' + poderes + "</div>"));
      cont.innerHTML = "";
      cont.appendChild(caja);
      requestAnimationFrame(function () {
        Array.prototype.forEach.call(caja.querySelectorAll("[data-w]"), function (b) { b.style.width = b.getAttribute("data-w") + "%"; });
      });
    }
    CLASES.forEach(function (c, i) {
      var b = el("button", "pestana", '<img class="pixel" src="img/sprites/' + c.sprites[0] + '.png" alt="">' + c.nombre);
      b.type = "button";
      b.setAttribute("role", "tab");
      b.addEventListener("click", function () { pintar(i); });
      pestanas.appendChild(b);
    });
    pintar(0);
    // flechas del teclado entre pestañas
    pestanas.addEventListener("keydown", function (ev) {
      if (ev.key === "ArrowRight") pintar((actual + 1) % CLASES.length);
      if (ev.key === "ArrowLeft") pintar((actual + CLASES.length - 1) % CLASES.length);
    });
  }

  // ------------------------------------------------------------------ monturas
  var MONTURAS = [
    ["buey", "Buey de carga", "Oficio · nivel 5", "Transporte: carga 22", "nv"],
    ["caballo", "Caballo", "Oficio · nivel 10", "Transporte: carga 6", "nv"],
    ["mnt_001", "Corcel blanco", "Gratis en el establo", "+40 % de velocidad", "gratis"],
    ["mnt_002", "Gallo de monta", "Gratis en el establo", "+38 % de velocidad", "gratis"],
    ["mnt_005", "Burro", "Gratis en el establo", "+40 % de velocidad", "gratis"],
    ["mnt_006", "Lobo blanco", "Gratis en el establo", "+30 % de velocidad", "gratis"],
    ["mnt_007", "Hámster de cofia", "Gratis en el establo", "+38 % de velocidad", "gratis"],
    ["mnt_008", "Zorro rojo", "Gratis en el establo", "+40 % de velocidad", "gratis"],
    ["mnt_009", "Jabalí ámbar", "Gratis en el establo", "+40 % de velocidad", "gratis"],
    ["mnt_026", "Corcel granate", "Gratis en el establo", "+34 % de velocidad", "gratis"],
    ["mnt_027", "Bisonte pardo", "Gratis en el establo", "+34 % de velocidad", "gratis"],
    ["mnt_028", "Hámster pardo", "Gratis en el establo", "+34 % de velocidad", "gratis"],
    ["mnt_029", "Corcel de nieve", "Gratis en el establo", "+34 % de velocidad", "gratis"],
    ["mnt_030", "Caballo castaño", "Gratis en el establo", "+34 % de velocidad", "gratis"],
    ["mnt_031", "Rana azul", "Gratis en el establo", "+34 % de velocidad", "gratis"],
    ["mnt_032", "Conejo escarlata", "Gratis en el establo", "+34 % de velocidad", "gratis"],
    ["mnt_033", "Jabalí dorado", "Gratis en el establo", "+34 % de velocidad", "gratis"],
    ["mnt_034", "Hámster del huevo", "Gratis en el establo", "+34 % de velocidad", "gratis"],
    ["mnt_035", "Lobo de melena", "Gratis en el establo", "+34 % de velocidad", "gratis"],
    ["mnt_036", "Gallo rojo", "Gratis en el establo", "+34 % de velocidad", "gratis"],
    ["mnt_037", "Cerdito rosa", "Gratis en el establo", "+34 % de velocidad", "gratis"],
    ["mnt_038", "Corcel borgoña", "Gratis en el establo", "+38 % de velocidad", "gratis"],
    ["mnt_039", "Hámster tostado", "Item Mall", "+38 % de velocidad", "mall"],
    ["mnt_040", "Lobo Aullador", "Item Mall", "+38 % de velocidad", "mall"],
    ["mnt_103", "Tortuga viajera", "Item Mall", "+42 % de velocidad", "mall"],
    ["mnt_104", "León dorado", "Item Mall", "+42 % de velocidad", "mall"],
    ["mnt_105", "Autómata azul", "Item Mall", "+42 % de velocidad", "mall"],
    ["mnt_143", "Escarabajo real", "Misión · El camino del explorador", "+42 % de velocidad", "mision"],
    ["mnt_226", "Espíritus de la noche", "Misión · El señor del Ocaso", "+46 % de velocidad", "mision"],
    ["mnt_239", "Centauro dorado", "Misión · La corona del Alba", "+42 % de velocidad", "mision"]
  ];
  var cm = document.getElementById("monturas-rejilla");
  if (cm) {
    MONTURAS.forEach(function (m) {
      var t = el("div", "tarjeta cristal rev",
        '<div class="lienzo"><img class="suave" loading="lazy" src="img/sprites/montura_' + m[0] + '.png" alt="' + m[1] + '"></div><h4>' + m[1] + "</h4><p>" + m[3] + '</p><span class="etiqueta ' + m[4] + '">' + m[2] + "</span>");
      cm.appendChild(t);
    });
  }

  // ------------------------------------------------------------------ criaturas notables
  var BESTIARIO = [
    ["minotauro_guerra", "Minotauro de guerra", "Nivel 31 · colina"],
    ["diablo_acorazado", "Diablo acorazado", "Nivel 32 · eclipse"],
    ["lancero_sombras", "Lancero de las sombras", "Nivel 33 · velo"],
    ["reptil_huesos", "Reptil de huesos", "Nivel 34 · cienaga"],
    ["duende_guerra", "Duende de guerra", "Nivel 35 · senda"],
    ["titan_hielo", "Titán de hielo", "Nivel 36 · pinar"],
    ["golem_amatista", "Gólem de amatista", "Nivel 37 · eclipse"],
    ["demonio_astado", "Demonio astado", "Nivel 38 · eclipse"],
    ["ent_ardiente", "Ent ardiente", "Nivel 39 · colina"],
    ["golem_escarcha", "Gólem de escarcha", "Nivel 40 · pinar"],
    ["jefe_dragon_pardo", "Dragón Pardo", "Jefe del mundo · nivel 40"],
    ["golem_cristal_oro", "Gólem de cristal dorado", "Nivel 41 · marea"],
    ["samurai_dorado", "Samurái de oro", "Nivel 42 · senda"],
    ["jefe_maestro_forja", "Maestro de la Forja", "Jefe de mazmorra · nivel 42"],
    ["barbaro_ancestral", "Bárbaro ancestral", "Nivel 43 · campos"],
    ["sacerdotisa_felina", "Sacerdotisa felina", "Nivel 44 · velo"],
    ["monje_carmesi", "Monje del desierto", "Nivel 45 · marea"],
    ["jefe_dragon_abisal", "Dragón Abisal", "Jefe del mundo · nivel 45"],
    ["samurai_espectral", "Samurái espectral", "Nivel 46 · eclipse"],
    ["lancero_esqueleto", "Jinete de huesos", "Nivel 47 · cienaga"],
    ["verdugo_esqueleto", "Verdugo de huesos", "Nivel 48 · cienaga"],
    ["golem_musgo_antiguo", "Gólem rúnico", "Nivel 49 · pinar"],
    ["espectro_hielo", "Espectro de hielo", "Nivel 50 · marea"],
    ["jefe_dragon_carmesi", "Dragón Carmesí", "Jefe del mundo · nivel 50"],
    ["jefe_gorila_ancestral", "Gorila Ancestral", "Jefe del mundo · nivel 50"],
    ["jefe_behemot_abismo", "Behemot del Abismo", "Jefe de mazmorra · nivel 50"]
  ];
  var cb = document.getElementById("bestiario-rejilla");
  if (cb) {
    BESTIARIO.forEach(function (m) {
      cb.appendChild(el("div", "tarjeta cristal rev", '<div class="lienzo"><img class="suave" loading="lazy" src="img/criaturas/' + m[0] + '.png" alt="' + m[1] + '"></div><h4>' + m[1] + '</h4><p>' + m[2] + "</p>"));
    });
  }

  // ------------------------------------------------------------------ menú móvil y estado de la cabecera
  var burger = document.getElementById("burger");
  var menu = document.getElementById("menu");
  if (burger && menu) {
    burger.addEventListener("click", function () { menu.classList.toggle("abierto"); });
    menu.addEventListener("click", function (e) { if (e.target.tagName === "A") menu.classList.remove("abierto"); });
  }

  // ------------------------------------------------------------------ aparición al hacer scroll
  var rev = document.querySelectorAll(".rev");
  if ("IntersectionObserver" in window) {
    var obs = new IntersectionObserver(function (entradas) {
      entradas.forEach(function (e) { if (e.isIntersecting) { e.target.classList.add("visible"); obs.unobserve(e.target); } });
    }, { threshold: 0.12 });
    var observar = function () { document.querySelectorAll(".rev:not(.visible)").forEach(function (e) { obs.observe(e); }); };
    observar();
    setTimeout(observar, 400);
  } else {
    rev.forEach(function (e) { e.classList.add("visible"); });
  }

  // ------------------------------------------------------------------ índice de la guía (resalta la sección que se lee)
  var indice = document.querySelectorAll(".indice a[href^='#']");
  if (indice.length && "IntersectionObserver" in window) {
    var mapa = {};
    indice.forEach(function (a) { mapa[a.getAttribute("href").slice(1)] = a; });
    var vistas = new IntersectionObserver(function (entradas) {
      entradas.forEach(function (e) {
        if (e.isIntersecting) {
          indice.forEach(function (a) { a.classList.remove("activo"); });
          var a = mapa[e.target.id];
          if (a) a.classList.add("activo");
        }
      });
    }, { rootMargin: "-20% 0px -70% 0px" });
    Object.keys(mapa).forEach(function (id) { var s = document.getElementById(id); if (s) vistas.observe(s); });
  }

  // ------------------------------------------------------------------ visor de imágenes
  var visor = el("div", "visor");
  var imgVisor = el("img");
  visor.appendChild(imgVisor);
  document.body.appendChild(visor);
  visor.addEventListener("click", function () { visor.classList.remove("abierto"); });
  document.addEventListener("keydown", function (e) { if (e.key === "Escape") visor.classList.remove("abierto"); });
  document.addEventListener("click", function (e) {
    var f = e.target.closest("[data-zoom]");
    if (!f) return;
    var im = f.tagName === "IMG" ? f : f.querySelector("img");
    if (!im) return;
    imgVisor.src = im.currentSrc || im.src;
    imgVisor.alt = im.alt;
    visor.classList.add("abierto");
  });

  // ------------------------------------------------------------------ datos de la descarga (descargas/version.json lo genera publicar.ps1)
  var info = document.querySelector("[data-version]");
  if (info) {
    fetch("descargas/version.json", { cache: "no-store" }).then(function (r) { return r.ok ? r.json() : null; }).then(function (v) {
      if (!v) return;
      document.querySelectorAll("[data-v='version']").forEach(function (e) { e.textContent = v.version; });
      document.querySelectorAll("[data-v='fecha']").forEach(function (e) { e.textContent = v.fecha; });
      document.querySelectorAll("[data-v='tamano']").forEach(function (e) { e.textContent = v.tamano; });
      document.querySelectorAll("[data-v='sha256']").forEach(function (e) { e.textContent = v.sha256; });
      document.querySelectorAll("[data-v='archivo']").forEach(function (e) { e.setAttribute("href", "descargas/" + v.archivo); e.setAttribute("download", v.archivo); });
    }).catch(function () {});
    var h = document.getElementById("hash");
    if (h) h.addEventListener("click", function () {
      var txt = h.querySelector("[data-v='sha256']").textContent;
      if (navigator.clipboard) navigator.clipboard.writeText(txt).then(function () { var s = h.querySelector("small"); var t = s.textContent; s.textContent = "Copiado"; setTimeout(function () { s.textContent = t; }, 1400); });
    });
  }
  var anio = document.getElementById("anio");
  if (anio) anio.textContent = new Date().getFullYear();
})();
