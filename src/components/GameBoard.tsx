import React from 'react';
import { useGameStore } from '../store/useGameStore';
import { GRID_SIZE } from '../types';
import clsx from 'clsx';

export const GameBoard: React.FC = () => {
  const { snake, food, status } = useGameStore();

  // Create grid cells
  const cells = Array.from({ length: GRID_SIZE * GRID_SIZE });

  return (
    <div 
      className="relative bg-dark-bg border-4 border-neon-blue rounded-lg shadow-[0_0_20px_#00ffff] overflow-hidden"
      style={{
        display: 'grid',
        gridTemplateColumns: `repeat(${GRID_SIZE}, 1fr)`,
        gridTemplateRows: `repeat(${GRID_SIZE}, 1fr)`,
        width: 'min(90vw, 500px)',
        height: 'min(90vw, 500px)',
      }}
    >
      {/* Grid Lines Overlay */}
      <div className="absolute inset-0 pointer-events-none opacity-20"
        style={{
          backgroundImage: `linear-gradient(#1a1a1a 1px, transparent 1px), linear-gradient(90deg, #1a1a1a 1px, transparent 1px)`,
          backgroundSize: `${100/GRID_SIZE}% ${100/GRID_SIZE}%`
        }}
      />

      {cells.map((_, index) => {
        const x = index % GRID_SIZE;
        const y = Math.floor(index / GRID_SIZE);
        
        const isSnakeHead = snake[0].x === x && snake[0].y === y;
        const isSnakeBody = snake.some((s, i) => i !== 0 && s.x === x && s.y === y);
        const isFood = food.x === x && food.y === y;

        return (
          <div
            key={index}
            className={clsx(
              'w-full h-full transition-all duration-100',
              isSnakeHead && 'bg-neon-green shadow-[0_0_15px_#39ff14] z-10 rounded-sm',
              isSnakeBody && 'bg-green-500/80 shadow-[0_0_5px_#39ff14] z-0 rounded-sm scale-90',
              isFood && 'bg-neon-pink shadow-[0_0_15px_#ff00ff] rounded-full animate-pulse z-10',
            )}
          />
        );
      })}

      {status === 'GAME_OVER' && (
        <div className="absolute inset-0 flex flex-col items-center justify-center bg-black/80 backdrop-blur-sm z-50">
          <h2 className="text-4xl font-retro text-neon-pink mb-4 animate-pulse">GAME OVER</h2>
          <button
            onClick={() => useGameStore.getState().resetGame()}
            className="px-6 py-3 bg-transparent border-2 border-neon-green text-neon-green font-retro hover:bg-neon-green hover:text-black transition-colors"
          >
            RETRY
          </button>
        </div>
      )}
      
      {status === 'IDLE' && (
        <div className="absolute inset-0 flex flex-col items-center justify-center bg-black/80 backdrop-blur-sm z-50">
          <h2 className="text-3xl font-retro text-neon-blue mb-8 text-center leading-relaxed">READY<br/>PLAYER ONE</h2>
          <button
            onClick={() => useGameStore.getState().startGame()}
            className="px-8 py-4 bg-neon-blue text-black font-bold font-cyber tracking-widest hover:bg-white hover:shadow-[0_0_20px_#ffffff] transition-all"
          >
            START SYSTEM
          </button>
        </div>
      )}
    </div>
  );
};
