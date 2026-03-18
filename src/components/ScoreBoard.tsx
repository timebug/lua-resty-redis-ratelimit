import React from 'react';
import { useGameStore } from '../store/useGameStore';
import { Trophy, Zap } from 'lucide-react';

export const ScoreBoard: React.FC = () => {
  const { score, highScore } = useGameStore();

  return (
    <div className="flex justify-between w-full max-w-[500px] mb-6 px-4">
      <div className="flex flex-col items-center">
        <div className="flex items-center gap-2 text-neon-pink mb-1">
          <Trophy size={20} />
          <span className="font-cyber text-xs tracking-widest uppercase">High Score</span>
        </div>
        <span className="font-retro text-xl text-white shadow-neon-pink">{highScore}</span>
      </div>

      <div className="flex flex-col items-center">
        <div className="flex items-center gap-2 text-neon-green mb-1">
          <Zap size={20} />
          <span className="font-cyber text-xs tracking-widest uppercase">Current</span>
        </div>
        <span className="font-retro text-xl text-white">{score}</span>
      </div>
    </div>
  );
};
