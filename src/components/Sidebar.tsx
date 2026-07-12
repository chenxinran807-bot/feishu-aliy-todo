import type React from "react";

type CategoryKey = "today" | "planned" | "all" | "completed";

interface CategoryDef {
  key: CategoryKey;
  label: string;
  icon: string;
  color: "blue" | "red" | "dark" | "gray";
  count: number;
}

interface SidebarProps {
  activeCategory: CategoryKey;
  onSelectCategory: (key: CategoryKey) => void;
  todayCount: number;
  plannedCount: number;
  allCount: number;
  completedCount: number;
  listCount?: number;
  listLabel?: string;
  onAddList?: () => void;
  tools?: React.ReactNode;
  track?: { name: string; displayPercent: number };
}

const categoryDefs = (counts: Record<CategoryKey, number>): CategoryDef[] => [
  { key: "today", label: "今天", icon: "📅", color: "blue", count: counts.today },
  { key: "planned", label: "计划", icon: "📆", color: "red", count: counts.planned },
  { key: "all", label: "全部", icon: "🗂️", color: "dark", count: counts.all },
  { key: "completed", label: "完成", icon: "✓", color: "gray", count: counts.completed },
];

export function Sidebar({
  activeCategory,
  onSelectCategory,
  todayCount,
  plannedCount,
  allCount,
  completedCount,
  listCount = 0,
  listLabel = "提醒事项",
  onAddList,
  tools,
  track,
}: SidebarProps) {
  const categories = categoryDefs({ today: todayCount, planned: plannedCount, all: allCount, completed: completedCount });

  return (
    <aside className="sidebar">
      <div className="sidebar__search">
        <span className="sidebar__search-icon">🔍</span>
        <input type="text" placeholder="搜索" aria-label="搜索待办" />
      </div>

      <nav className="category-grid" aria-label="分类">
        {categories.map((cat) => (
          <button
            key={cat.key}
            type="button"
            className={`category-card category-card--${cat.color} ${activeCategory === cat.key ? "category-card--active" : ""}`}
            onClick={() => onSelectCategory(cat.key)}
            aria-pressed={activeCategory === cat.key}
          >
            <span className="category-card__top">
              <span className={`category-card__icon category-card__icon--${cat.color}`}>{cat.icon}</span>
              <span className="category-card__count">{cat.count}</span>
            </span>
            <span className="category-card__label">{cat.label}</span>
          </button>
        ))}
      </nav>

      <div>
        <div className="sidebar__section-title">
          <span>我的列表</span>
          <button type="button" className="sidebar__update-btn">
            更新
          </button>
        </div>
        <nav className="list-nav" aria-label="我的列表">
          <button
            type="button"
            className={`list-nav__item ${activeCategory === "all" ? "list-nav__item--active" : ""}`}
            onClick={() => onSelectCategory("all")}
          >
            <span className="list-nav__icon">☰</span>
            <span className="list-nav__label">{listLabel}</span>
            <span className="list-nav__count">{listCount}</span>
          </button>
        </nav>
      </div>

      <button type="button" className="sidebar__add-list" onClick={onAddList}>
        <span>＋</span>
        <span>添加列表</span>
      </button>

      {track ? (
        <div className="progress-track">
          <div className="progress-track__header">
            <span>{track.name}</span>
            <span>{track.displayPercent}%</span>
          </div>
          <div className="progress-track__bar">
            <span style={{ width: `${track.displayPercent}%` }} />
          </div>
        </div>
      ) : null}

      {tools ? (
        <div style={{ display: "grid", gap: 12 }}>
          {tools}
        </div>
      ) : null}
    </aside>
  );
}

export type { CategoryKey };
