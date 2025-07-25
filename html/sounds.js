// sounds.js - controle de sons da NUI
function playBeep() {
    var audio = document.getElementById('beep');
    audio.currentTime = 0;
    audio.volume = 1.0;
    audio.play();
}
function playBuzzer() {
    document.getElementById('buzzer').currentTime = 0;
    document.getElementById('buzzer').play();
}
function playStart() {
    var audio = document.getElementById('start');
    audio.currentTime = 0;
    audio.volume = 1.0;
    audio.play();
}
// Exemplo de integração:
// playBeep() a cada luz, playStart() no verde, playBuzzer() ao queimar

document.getElementById('start').volume = 1.0; // volume máximo
// Faça o mesmo para outros sons, se quiser:
document.getElementById('beep').volume = 1.0;
document.getElementById('buzzer').volume = 1.0;
