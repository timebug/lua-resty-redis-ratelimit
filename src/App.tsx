import { useSnakeGame } from './hooks/useSnakeGame';
import { GameBoard } from './components/GameBoard';
import { ScoreBoard } from './components/ScoreBoard';
import { Controls } from './components/Controls';
import { Github } from 'lucide-react';

function App() {
  // Initialize game loop
  useSnakeGame();

  return (
    <div className="min-h-screen bg-dark-bg text-white flex flex-col items-center justify-center relative overflow-hidden font-sans selection:bg-neon-pink selection:text-white">
      {/* CRT Scanline Overlay */}
      <div className="scanline"></div>
      
      {/* Background Glow */}
      <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[600px] bg-neon-blue/5 rounded-full blur-[100px] pointer-events-none"></div>

      {/* Header */}
      <header className="mb-8 z-10 text-center">
        <h1 className="text-4xl md:text-6xl font-retro text-transparent bg-clip-text bg-gradient-to-r from-neon-green to-neon-blue drop-shadow-[0_0_10px_rgba(57,255,20,0.8)] animate-pulse">
          NEON SNAKE
        </h1>
        <p className="text-neon-pink font-cyber text-sm mt-2 tracking-[0.3em] uppercase opacity-80">
          Cyberpunk Edition
        </p>
      </header>

      {/* Game Container */}
      <main className="z-10 flex flex-col items-center w-full px-4">
        <ScoreBoard />
        <GameBoard />
        <Controls />
      </main>

      {/* Footer */}
      <footer className="mt-12 z-10 text-gray-500 text-xs font-cyber flex items-center gap-2 opacity-50 hover:opacity-100 transition-opacity">
        <Github size={14} />
        <span>BUILT WITH REACT + ZUSTAND</span>
      </footer>
    </div>
  );
}

export default App;
