// main.js - lógica da NUI (exceto sons)

window.addEventListener('message', function (event) {
  const data = event.data;
  const lightBox = document.getElementById("lightBox");
  const resultBox = document.getElementById("resultBox");
  const resultTitle = document.getElementById("resultTitle");
  const resultTime = document.getElementById("resultTime");
  const rankingBox = document.getElementById("rankingBox");
  const rankingList = document.getElementById("rankingList");
  const countdown = document.getElementById("countdown");
  const historyBox = document.getElementById("historyBox");
  const historyList = document.getElementById("historyList");
  const recordsList = document.getElementById("recordsList");
  const achievementsList = document.getElementById("achievementsList");

  // NOVO: Handler para sequência sincronizada de semáforo/contador
  if (data.showCountdown) {
    resultBox.style.display = "none";
    lightBox.style.display = "flex";
    startTrafficLightSequence();
    return;
  }

  if (data.state) updateLight(data.state);

  if (data.hideLight) {
    lightBox.style.display = "none";
    countdown.style.display = "none";
  }

  if (data.showResult) {
    resultBox.style.display = "block";
    if (data.burned) {
      resultTitle.innerText = "LARGADA QUEIMADA!";
      resultTitle.style.color = "#e74c3c";
      setNeonEffect(resultTitle, "#e74c3c");
    } else {
      resultTitle.innerText = "CORRIDA FINALIZADA!";
      resultTitle.style.color = "#2ecc71";
      setNeonEffect(resultTitle, "#2ecc71");
    }
    resultTime.innerText = `Tempo: ${data.time.toFixed(2)}s`;
    let best = (typeof data.personalBest === 'number') ? data.personalBest : personalBest;
    if (!data.burned) {
      if (personalBest === null || data.time < personalBest) personalBest = data.time;
      if (typeof data.personalBest === 'number') personalBest = data.personalBest;
      rankingList.innerHTML = `
        <li><strong>Melhor tempo:</strong> ${personalBest.toFixed(2)}s</li>
        <li><strong>Último tempo:</strong> ${data.time.toFixed(2)}s</li>
      `;
      rankingBox.style.display = "block";
      setTimeout(() => { rankingBox.style.display = "none"; }, 10000);
    }
  }

  if (data.reset) {
    resultBox.style.display = "none";
    lightBox.style.display = "none";
    countdown.style.display = "none";
    historyBox.style.display = "none";
  }

  if (data.showLight) {
    lightBox.style.display = "flex";
    updateLight("red");
  }

  // Painel de histórico, recordes e conquistas
  if (data.showHistory && Array.isArray(data.history)) {
    historyBox.style.display = "block";
    historyList.innerHTML = data.history.length ? data.history.map(c => `<li>${c.track} - <b>${Number(c.time).toFixed(2)}s</b> em ${c.date} ${c.venceu == 1 ? '🏆' : ''}</li>`).join('') : '<li>Nenhuma corrida registrada.</li>';
  }
  if (data.showRecords && Array.isArray(data.records)) {
    recordsList.innerHTML = data.records.length ? data.records.map(r => `<li>${r.track}: <b>${Number(r.best_time).toFixed(2)}s</b></li>`).join('') : '<li>Nenhum recorde registrado.</li>';
  }
  if (data.showAchievements) {
    let ach = '';
    if (data.weeklyBest && data.weeklyBest.best_time) {
      ach += `<li>Melhor tempo da semana: <b>${data.weeklyBest.best_time.toFixed(2)}s</b> (${data.weeklyBest.track})</li>`;
    }
    if (typeof data.winStreak === 'number') {
      ach += `<li>Sequência de vitórias: <b>${data.winStreak}</b></li>`;
    }
    achievementsList.innerHTML = ach || '<li>Nenhuma conquista registrada.</li>';
  }
});

function closeHistory() {
  document.getElementById('historyBox').style.display = 'none';
}

// Funções utilitárias (devem ser movidas do HTML para cá)
let personalBest = null;
let countdownInterval = null;

function setNeonEffect(element, color) {
  element.style.textShadow = `0 0 8px ${color}, 0 0 16px ${color}, 0 0 32px ${color}`;
}

function updateSvgLight(state) {
  const lights = {
    red: document.getElementById("redLight"),
    yellow: document.getElementById("yellowLight"),
    green: document.getElementById("greenLight")
  };
  Object.keys(lights).forEach(key => {
    lights[key].classList.remove("glow-red", "glow-yellow", "glow-green");
    lights[key].setAttribute("fill", key === state ? {
      red: "#ff4d4d",
      yellow: "#ffe066",
      green: "#32ff7e"
    }[key] : {
      red: "#8b0b28",
      yellow: "#ab8c25",
      green: "#0f7035"
    }[key]);
  });
  if (state === "red") lights.red.classList.add("glow-red");
  if (state === "yellow") lights.yellow.classList.add("glow-yellow");
  if (state === "green") lights.green.classList.add("glow-green");
}

function updateLight(state) {
  const lightText = document.getElementById("lightText");
  const states = {
    red: "ATENÇÃO!",
    yellow: "PREPARAR...",
    green: "CORRER!"
  };
  lightText.innerText = states[state] || "AGUARDE";
  setNeonEffect(lightText, state === "red" ? "#ff4d4d" : state === "yellow" ? "#ffe066" : state === "green" ? "#32ff7e" : "#fff");
  updateSvgLight(state);
}

function startTrafficLightSequence(callback) {
  const countdown = document.getElementById("countdown");
  const lightText = document.getElementById("lightText");
  const sequence = [
    { state: 'red',    text: '3', color: '#ff4d4d', light: 'red', sound: 'beep' },
    { state: 'yellow', text: '2', color: '#ffe066', light: 'yellow', sound: 'beep' },
    { state: 'green',  text: '1', color: '#32ff7e', light: 'green', sound: 'beep' },
    { state: 'green',  text: 'VAI!', color: '#32ff7e', light: 'green', sound: 'start' }
  ];
  let idx = 0;
  countdown.style.display = "block";
  function nextStep() {
    if (idx < sequence.length) {
      const step = sequence[idx];
      updateLight(step.light);
      if (step.sound === 'beep') playBeep();
      if (step.sound === 'start') playStart();
      countdown.innerText = step.text;
      setNeonEffect(countdown, step.color);
      if (step.text === 'VAI!') {
        setTimeout(() => {
          lightBox.style.display = "none";
          lightText.innerText = "";
          if (window.parent) {
            window.parent.postMessage({ type: 'signalDone' }, '*');
          }
          if (callback) callback();
        }, 600);
      } else {
        setTimeout(() => {
          idx++;
          nextStep();
        }, 900);
      }
    }
  }
  nextStep();
}

// Funções globais para sons (usadas pelo semáforo)
function playBeep() {
  var audio = document.getElementById('beep');
  if (audio) {
    audio.currentTime = 0;
    audio.volume = 1.0;
    audio.play();
  }
}
function playStart() {
  var audio = document.getElementById('start');
  if (audio) {
    audio.currentTime = 0;
    audio.volume = 1.0;
    audio.play();
  }
}
