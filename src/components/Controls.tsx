import React from 'react';
import { useGameStore } from '../store/useGameStore';
import { ArrowUp, ArrowDown, ArrowLeft, ArrowRight, Play, Pause, RefreshCw } from 'lucide-react';
import clsx from 'clsx';

export const Controls: React.FC = () => {
  const { status, setNextDirection, startGame, pauseGame, resetGame } = useGameStore();

  const handleDir = (dir: 'UP' | 'DOWN' | 'LEFT' | 'RIGHT') => {
    setNextDirection(dir);
  };

  return (
    <div className="mt-8 flex flex-col items-center gap-6 w-full max-w-[500px]">
      {/* Game State Controls */}
      <div className="flex gap-4">
        {status === 'PLAYING' || status === 'PAUSED' ? (
          <button
            onClick={pauseGame}
            className="p-3 border border-neon-blue rounded-full text-neon-blue hover:bg-neon-blue hover:text-black transition-all"
          >
            {status === 'PLAYING' ? <Pause size={24} /> : <Play size={24} />}
          </button>
        ) : null}
        
        <button
          onClick={resetGame}
          className="p-3 border border-red-500 rounded-full text-red-500 hover:bg-red-500 hover:text-black transition-all"
        >
          <RefreshCw size={24} />
        </button>
      </div>

      {/* Mobile D-Pad (Visible mainly on mobile via CSS, but good to have for mouse users too) */}
      <div className="grid grid-cols-3 gap-2 md:hidden">
        <div />
        <button 
          className="p-4 bg-gray-800 rounded-lg active:bg-neon-blue active:text-black transition-colors"
          onPointerDown={() => handleDir('UP')}
        >
          <ArrowUp />
        </button>
        <div />
        
        <button 
          className="p-4 bg-gray-800 rounded-lg active:bg-neon-blue active:text-black transition-colors"
          onPointerDown={() => handleDir('LEFT')}
        >
          <ArrowLeft />
        </button>
        <div className="w-12 h-12 rounded-full bg-gray-900 border border-gray-700" />
        <button 
          className="p-4 bg-gray-800 rounded-lg active:bg-neon-blue active:text-black transition-colors"
          onPointerDown={() => handleDir('RIGHT')}
        >
          <ArrowRight />
        </button>
        
        <div />
        <button 
          className="p-4 bg-gray-800 rounded-lg active:bg-neon-blue active:text-black transition-colors"
          onPointerDown={() => handleDir('DOWN')}
        >
          <ArrowDown />
        </button>
        <div />
      </div>

      <div className="hidden md:block text-gray-500 text-xs font-cyber mt-4">
        USE ARROW KEYS OR SPACE TO START
      </div>
    </div>
  );
};
