-- =====================================================================================
-- 0031 · Sistemas de puntuación por liga. Al crear la liga, el administrador elige:
--        · Cyclonomy (por defecto): las categorías del juego; el WorldTour, dividido en WT A y WT B (por defecto)
--          o junto en una sola categoría WT.
--        · UCI: el baremo oficial UCI 2026 (hombres élite) según la clase de cada carrera, con puntos de etapa,
--          de líder de la general cada día y, en las Grandes Vueltas, de regularidad y montaña.
--        Cada etapa se puntúa en los tres sistemas a la vez (rider_score.scheme) y cada liga suma el suyo.
-- =====================================================================================

alter table public.league add column if not exists scoring_system text not null default 'cyclonomy'
  check (scoring_system in ('cyclonomy', 'uci'));
alter table public.league add column if not exists wt_split boolean not null default true;

-- ---------------------------------------------------------------- categorías de Cyclonomy: WT A, WT B y WT junto
update public.race_category set name = 'WT A' where code = 'MWT';
update public.race_category set name = 'WT B' where code = 'SWT';
insert into public.race_category (code, name, depth_level, max_entries)
values ('WT', 'WorldTour', 1, 7) on conflict (code) do nothing;
-- WT junto (ligas sin dividir): el punto medio entre WT A y WT B (90 % de WT A)
insert into public.scoring_rule (category, kind, position, points)
select 'WT', kind, position, round(points * 0.9)::int from public.scoring_rule where category = 'MWT'
on conflict (category, kind, position) do update set points = excluded.points;

-- WT A: la lista de Cyclonomy; el resto del WorldTour (sin Grandes Vueltas ni Monumentos), WT B
update public.category_rule set pattern = '^(strade-bianche|paris-nice|tirreno-adriatico|volta-a-catalunya|e3-|gent-wevelgem|itzulia|amstel-gold-race|la-fleche-wallonne|fleche-wallonne|dauphine|tour-auvergne-rhone-alpes|tour-de-suisse|gp-quebec|gp-montreal|san-sebastian)' where category = 'MWT';
update public.race set category = public.classify_race(pcs_slug, name, uci_class)
where category in ('MWT', 'SWT') and public.classify_race(pcs_slug, name, uci_class) is not null;
update public.rider_history_result set category = case when race_slug ~ '^(strade-bianche|paris-nice|tirreno-adriatico|volta-a-catalunya|e3-|gent-wevelgem|itzulia|amstel-gold-race|la-fleche-wallonne|fleche-wallonne|dauphine|tour-auvergne-rhone-alpes|tour-de-suisse|gp-quebec|gp-montreal|san-sebastian)' then 'MWT' else 'SWT' end
where category in ('MWT', 'SWT');

-- ---------------------------------------------------------------- baremo UCI
create table if not exists public.uci_rule (
  grp       text not null,     -- GT.A (Tour), GT.B (Giro, Vuelta), Monument, WO, WO.TT, C1, C2, CC, CC.TT, NC, NC.TT, Pro, 1
  kind      text not null check (kind in ('oneday', 'gc', 'stage', 'leader', 'points_final', 'kom_final')),
  position  smallint not null check (position >= 1),
  points    integer not null check (points >= 0),
  primary key (grp, kind, position)
);
alter table public.uci_rule enable row level security;
create policy read_all on public.uci_rule for select to authenticated using (true);
delete from public.uci_rule;
insert into public.uci_rule (grp, kind, position, points) values
('GT.A','oneday',1,1300),
('GT.A','oneday',2,1040),
('GT.A','oneday',3,880),
('GT.A','oneday',4,750),
('GT.A','oneday',5,620),
('GT.A','oneday',6,520),
('GT.A','oneday',7,425),
('GT.A','oneday',8,360),
('GT.A','oneday',9,295),
('GT.A','oneday',10,230),
('GT.A','oneday',11,190),
('GT.A','oneday',12,165),
('GT.A','oneday',13,140),
('GT.A','oneday',14,110),
('GT.A','oneday',15,100),
('GT.A','oneday',16,90),
('GT.A','oneday',17,85),
('GT.A','oneday',18,80),
('GT.A','oneday',19,70),
('GT.A','oneday',20,60),
('GT.A','oneday',21,50),
('GT.A','oneday',22,50),
('GT.A','oneday',23,50),
('GT.A','oneday',24,50),
('GT.A','oneday',25,50),
('GT.A','oneday',26,40),
('GT.A','oneday',27,40),
('GT.A','oneday',28,40),
('GT.A','oneday',29,40),
('GT.A','oneday',30,40),
('GT.A','oneday',31,35),
('GT.A','oneday',32,35),
('GT.A','oneday',33,35),
('GT.A','oneday',34,35),
('GT.A','oneday',35,35),
('GT.A','oneday',36,35),
('GT.A','oneday',37,35),
('GT.A','oneday',38,35),
('GT.A','oneday',39,35),
('GT.A','oneday',40,35),
('GT.A','oneday',41,25),
('GT.A','oneday',42,25),
('GT.A','oneday',43,25),
('GT.A','oneday',44,25),
('GT.A','oneday',45,25),
('GT.A','oneday',46,25),
('GT.A','oneday',47,25),
('GT.A','oneday',48,25),
('GT.A','oneday',49,25),
('GT.A','oneday',50,25),
('GT.A','oneday',51,20),
('GT.A','oneday',52,20),
('GT.A','oneday',53,20),
('GT.A','oneday',54,20),
('GT.A','oneday',55,20),
('GT.A','oneday',56,15),
('GT.A','oneday',57,15),
('GT.A','oneday',58,15),
('GT.A','oneday',59,15),
('GT.A','oneday',60,15),
('GT.A','gc',1,1300),
('GT.A','gc',2,1040),
('GT.A','gc',3,880),
('GT.A','gc',4,750),
('GT.A','gc',5,620),
('GT.A','gc',6,520),
('GT.A','gc',7,425),
('GT.A','gc',8,360),
('GT.A','gc',9,295),
('GT.A','gc',10,230),
('GT.A','gc',11,190),
('GT.A','gc',12,165),
('GT.A','gc',13,140),
('GT.A','gc',14,110),
('GT.A','gc',15,100),
('GT.A','gc',16,90),
('GT.A','gc',17,85),
('GT.A','gc',18,80),
('GT.A','gc',19,70),
('GT.A','gc',20,60),
('GT.A','gc',21,50),
('GT.A','gc',22,50),
('GT.A','gc',23,50),
('GT.A','gc',24,50),
('GT.A','gc',25,50),
('GT.A','gc',26,40),
('GT.A','gc',27,40),
('GT.A','gc',28,40),
('GT.A','gc',29,40),
('GT.A','gc',30,40),
('GT.A','gc',31,35),
('GT.A','gc',32,35),
('GT.A','gc',33,35),
('GT.A','gc',34,35),
('GT.A','gc',35,35),
('GT.A','gc',36,35),
('GT.A','gc',37,35),
('GT.A','gc',38,35),
('GT.A','gc',39,35),
('GT.A','gc',40,35),
('GT.A','gc',41,25),
('GT.A','gc',42,25),
('GT.A','gc',43,25),
('GT.A','gc',44,25),
('GT.A','gc',45,25),
('GT.A','gc',46,25),
('GT.A','gc',47,25),
('GT.A','gc',48,25),
('GT.A','gc',49,25),
('GT.A','gc',50,25),
('GT.A','gc',51,20),
('GT.A','gc',52,20),
('GT.A','gc',53,20),
('GT.A','gc',54,20),
('GT.A','gc',55,20),
('GT.A','gc',56,15),
('GT.A','gc',57,15),
('GT.A','gc',58,15),
('GT.A','gc',59,15),
('GT.A','gc',60,15),
('GT.A','stage',1,210),
('GT.A','stage',2,150),
('GT.A','stage',3,110),
('GT.A','stage',4,90),
('GT.A','stage',5,70),
('GT.A','stage',6,55),
('GT.A','stage',7,45),
('GT.A','stage',8,40),
('GT.A','stage',9,35),
('GT.A','stage',10,30),
('GT.A','stage',11,25),
('GT.A','stage',12,20),
('GT.A','stage',13,15),
('GT.A','stage',14,10),
('GT.A','stage',15,5),
('GT.A','leader',1,25),
('GT.A','points_final',1,210),
('GT.A','points_final',2,150),
('GT.A','points_final',3,110),
('GT.A','kom_final',1,210),
('GT.A','kom_final',2,150),
('GT.A','kom_final',3,110),
('GT.B','oneday',1,1100),
('GT.B','oneday',2,885),
('GT.B','oneday',3,750),
('GT.B','oneday',4,600),
('GT.B','oneday',5,495),
('GT.B','oneday',6,415),
('GT.B','oneday',7,340),
('GT.B','oneday',8,285),
('GT.B','oneday',9,235),
('GT.B','oneday',10,180),
('GT.B','oneday',11,155),
('GT.B','oneday',12,130),
('GT.B','oneday',13,110),
('GT.B','oneday',14,90),
('GT.B','oneday',15,80),
('GT.B','oneday',16,75),
('GT.B','oneday',17,70),
('GT.B','oneday',18,60),
('GT.B','oneday',19,55),
('GT.B','oneday',20,50),
('GT.B','oneday',21,50),
('GT.B','oneday',22,50),
('GT.B','oneday',23,50),
('GT.B','oneday',24,50),
('GT.B','oneday',25,50),
('GT.B','oneday',26,30),
('GT.B','oneday',27,30),
('GT.B','oneday',28,30),
('GT.B','oneday',29,30),
('GT.B','oneday',30,30),
('GT.B','oneday',31,25),
('GT.B','oneday',32,25),
('GT.B','oneday',33,25),
('GT.B','oneday',34,25),
('GT.B','oneday',35,25),
('GT.B','oneday',36,25),
('GT.B','oneday',37,25),
('GT.B','oneday',38,25),
('GT.B','oneday',39,25),
('GT.B','oneday',40,25),
('GT.B','oneday',41,20),
('GT.B','oneday',42,20),
('GT.B','oneday',43,20),
('GT.B','oneday',44,20),
('GT.B','oneday',45,20),
('GT.B','oneday',46,20),
('GT.B','oneday',47,20),
('GT.B','oneday',48,20),
('GT.B','oneday',49,20),
('GT.B','oneday',50,20),
('GT.B','oneday',51,15),
('GT.B','oneday',52,15),
('GT.B','oneday',53,15),
('GT.B','oneday',54,15),
('GT.B','oneday',55,15),
('GT.B','oneday',56,10),
('GT.B','oneday',57,10),
('GT.B','oneday',58,10),
('GT.B','oneday',59,10),
('GT.B','oneday',60,10),
('GT.B','gc',1,1100),
('GT.B','gc',2,885),
('GT.B','gc',3,750),
('GT.B','gc',4,600),
('GT.B','gc',5,495),
('GT.B','gc',6,415),
('GT.B','gc',7,340),
('GT.B','gc',8,285),
('GT.B','gc',9,235),
('GT.B','gc',10,180),
('GT.B','gc',11,155),
('GT.B','gc',12,130),
('GT.B','gc',13,110),
('GT.B','gc',14,90),
('GT.B','gc',15,80),
('GT.B','gc',16,75),
('GT.B','gc',17,70),
('GT.B','gc',18,60),
('GT.B','gc',19,55),
('GT.B','gc',20,50),
('GT.B','gc',21,50),
('GT.B','gc',22,50),
('GT.B','gc',23,50),
('GT.B','gc',24,50),
('GT.B','gc',25,50),
('GT.B','gc',26,30),
('GT.B','gc',27,30),
('GT.B','gc',28,30),
('GT.B','gc',29,30),
('GT.B','gc',30,30),
('GT.B','gc',31,25),
('GT.B','gc',32,25),
('GT.B','gc',33,25),
('GT.B','gc',34,25),
('GT.B','gc',35,25),
('GT.B','gc',36,25),
('GT.B','gc',37,25),
('GT.B','gc',38,25),
('GT.B','gc',39,25),
('GT.B','gc',40,25),
('GT.B','gc',41,20),
('GT.B','gc',42,20),
('GT.B','gc',43,20),
('GT.B','gc',44,20),
('GT.B','gc',45,20),
('GT.B','gc',46,20),
('GT.B','gc',47,20),
('GT.B','gc',48,20),
('GT.B','gc',49,20),
('GT.B','gc',50,20),
('GT.B','gc',51,15),
('GT.B','gc',52,15),
('GT.B','gc',53,15),
('GT.B','gc',54,15),
('GT.B','gc',55,15),
('GT.B','gc',56,10),
('GT.B','gc',57,10),
('GT.B','gc',58,10),
('GT.B','gc',59,10),
('GT.B','gc',60,10),
('GT.B','stage',1,180),
('GT.B','stage',2,130),
('GT.B','stage',3,95),
('GT.B','stage',4,80),
('GT.B','stage',5,60),
('GT.B','stage',6,45),
('GT.B','stage',7,40),
('GT.B','stage',8,35),
('GT.B','stage',9,30),
('GT.B','stage',10,25),
('GT.B','stage',11,20),
('GT.B','stage',12,15),
('GT.B','stage',13,10),
('GT.B','stage',14,5),
('GT.B','stage',15,2),
('GT.B','leader',1,20),
('GT.B','points_final',1,180),
('GT.B','points_final',2,130),
('GT.B','points_final',3,95),
('GT.B','kom_final',1,180),
('GT.B','kom_final',2,130),
('GT.B','kom_final',3,95),
('Monument','oneday',1,800),
('Monument','oneday',2,640),
('Monument','oneday',3,520),
('Monument','oneday',4,440),
('Monument','oneday',5,360),
('Monument','oneday',6,280),
('Monument','oneday',7,240),
('Monument','oneday',8,200),
('Monument','oneday',9,160),
('Monument','oneday',10,135),
('Monument','oneday',11,110),
('Monument','oneday',12,95),
('Monument','oneday',13,85),
('Monument','oneday',14,65),
('Monument','oneday',15,55),
('Monument','oneday',16,50),
('Monument','oneday',17,50),
('Monument','oneday',18,50),
('Monument','oneday',19,50),
('Monument','oneday',20,50),
('Monument','oneday',21,30),
('Monument','oneday',22,30),
('Monument','oneday',23,30),
('Monument','oneday',24,30),
('Monument','oneday',25,30),
('Monument','oneday',26,30),
('Monument','oneday',27,30),
('Monument','oneday',28,30),
('Monument','oneday',29,30),
('Monument','oneday',30,30),
('Monument','oneday',31,15),
('Monument','oneday',32,15),
('Monument','oneday',33,15),
('Monument','oneday',34,15),
('Monument','oneday',35,15),
('Monument','oneday',36,15),
('Monument','oneday',37,15),
('Monument','oneday',38,15),
('Monument','oneday',39,15),
('Monument','oneday',40,15),
('Monument','oneday',41,15),
('Monument','oneday',42,15),
('Monument','oneday',43,15),
('Monument','oneday',44,15),
('Monument','oneday',45,15),
('Monument','oneday',46,15),
('Monument','oneday',47,15),
('Monument','oneday',48,15),
('Monument','oneday',49,15),
('Monument','oneday',50,15),
('Monument','oneday',51,10),
('Monument','oneday',52,10),
('Monument','oneday',53,10),
('Monument','oneday',54,10),
('Monument','oneday',55,10),
('Monument','oneday',56,5),
('Monument','oneday',57,5),
('Monument','oneday',58,5),
('Monument','oneday',59,5),
('Monument','oneday',60,5),
('Monument','gc',1,800),
('Monument','gc',2,640),
('Monument','gc',3,520),
('Monument','gc',4,440),
('Monument','gc',5,360),
('Monument','gc',6,280),
('Monument','gc',7,240),
('Monument','gc',8,200),
('Monument','gc',9,160),
('Monument','gc',10,135),
('Monument','gc',11,110),
('Monument','gc',12,95),
('Monument','gc',13,85),
('Monument','gc',14,65),
('Monument','gc',15,55),
('Monument','gc',16,50),
('Monument','gc',17,50),
('Monument','gc',18,50),
('Monument','gc',19,50),
('Monument','gc',20,50),
('Monument','gc',21,30),
('Monument','gc',22,30),
('Monument','gc',23,30),
('Monument','gc',24,30),
('Monument','gc',25,30),
('Monument','gc',26,30),
('Monument','gc',27,30),
('Monument','gc',28,30),
('Monument','gc',29,30),
('Monument','gc',30,30),
('Monument','gc',31,15),
('Monument','gc',32,15),
('Monument','gc',33,15),
('Monument','gc',34,15),
('Monument','gc',35,15),
('Monument','gc',36,15),
('Monument','gc',37,15),
('Monument','gc',38,15),
('Monument','gc',39,15),
('Monument','gc',40,15),
('Monument','gc',41,15),
('Monument','gc',42,15),
('Monument','gc',43,15),
('Monument','gc',44,15),
('Monument','gc',45,15),
('Monument','gc',46,15),
('Monument','gc',47,15),
('Monument','gc',48,15),
('Monument','gc',49,15),
('Monument','gc',50,15),
('Monument','gc',51,10),
('Monument','gc',52,10),
('Monument','gc',53,10),
('Monument','gc',54,10),
('Monument','gc',55,10),
('Monument','gc',56,5),
('Monument','gc',57,5),
('Monument','gc',58,5),
('Monument','gc',59,5),
('Monument','gc',60,5),
('WO','oneday',1,900),
('WO','oneday',2,715),
('WO','oneday',3,600),
('WO','oneday',4,490),
('WO','oneday',5,410),
('WO','oneday',6,340),
('WO','oneday',7,265),
('WO','oneday',8,225),
('WO','oneday',9,190),
('WO','oneday',10,150),
('WO','oneday',11,130),
('WO','oneday',12,105),
('WO','oneday',13,90),
('WO','oneday',14,75),
('WO','oneday',15,60),
('WO','oneday',16,50),
('WO','oneday',17,45),
('WO','oneday',18,45),
('WO','oneday',19,45),
('WO','oneday',20,45),
('WO','oneday',21,45),
('WO','oneday',22,30),
('WO','oneday',23,30),
('WO','oneday',24,30),
('WO','oneday',25,30),
('WO','oneday',26,30),
('WO','oneday',27,30),
('WO','oneday',28,30),
('WO','oneday',29,30),
('WO','oneday',30,30),
('WO','oneday',31,30),
('WO','oneday',32,15),
('WO','oneday',33,15),
('WO','oneday',34,15),
('WO','oneday',35,15),
('WO','oneday',36,15),
('WO','oneday',37,15),
('WO','oneday',38,15),
('WO','oneday',39,15),
('WO','oneday',40,15),
('WO','oneday',41,15),
('WO','oneday',42,15),
('WO','oneday',43,15),
('WO','oneday',44,15),
('WO','oneday',45,15),
('WO','oneday',46,15),
('WO','oneday',47,15),
('WO','oneday',48,15),
('WO','oneday',49,15),
('WO','oneday',50,15),
('WO','oneday',51,10),
('WO','oneday',52,10),
('WO','oneday',53,10),
('WO','oneday',54,10),
('WO','oneday',55,10),
('WO','oneday',56,5),
('WO','oneday',57,5),
('WO','oneday',58,5),
('WO','oneday',59,5),
('WO','oneday',60,5),
('WO','gc',1,900),
('WO','gc',2,715),
('WO','gc',3,600),
('WO','gc',4,490),
('WO','gc',5,410),
('WO','gc',6,340),
('WO','gc',7,265),
('WO','gc',8,225),
('WO','gc',9,190),
('WO','gc',10,150),
('WO','gc',11,130),
('WO','gc',12,105),
('WO','gc',13,90),
('WO','gc',14,75),
('WO','gc',15,60),
('WO','gc',16,50),
('WO','gc',17,45),
('WO','gc',18,45),
('WO','gc',19,45),
('WO','gc',20,45),
('WO','gc',21,45),
('WO','gc',22,30),
('WO','gc',23,30),
('WO','gc',24,30),
('WO','gc',25,30),
('WO','gc',26,30),
('WO','gc',27,30),
('WO','gc',28,30),
('WO','gc',29,30),
('WO','gc',30,30),
('WO','gc',31,30),
('WO','gc',32,15),
('WO','gc',33,15),
('WO','gc',34,15),
('WO','gc',35,15),
('WO','gc',36,15),
('WO','gc',37,15),
('WO','gc',38,15),
('WO','gc',39,15),
('WO','gc',40,15),
('WO','gc',41,15),
('WO','gc',42,15),
('WO','gc',43,15),
('WO','gc',44,15),
('WO','gc',45,15),
('WO','gc',46,15),
('WO','gc',47,15),
('WO','gc',48,15),
('WO','gc',49,15),
('WO','gc',50,15),
('WO','gc',51,10),
('WO','gc',52,10),
('WO','gc',53,10),
('WO','gc',54,10),
('WO','gc',55,10),
('WO','gc',56,5),
('WO','gc',57,5),
('WO','gc',58,5),
('WO','gc',59,5),
('WO','gc',60,5),
('WO.TT','oneday',1,455),
('WO.TT','oneday',2,325),
('WO.TT','oneday',3,260),
('WO.TT','oneday',4,195),
('WO.TT','oneday',5,165),
('WO.TT','oneday',6,130),
('WO.TT','oneday',7,110),
('WO.TT','oneday',8,90),
('WO.TT','oneday',9,80),
('WO.TT','oneday',10,65),
('WO.TT','oneday',11,55),
('WO.TT','oneday',12,40),
('WO.TT','oneday',13,30),
('WO.TT','oneday',14,25),
('WO.TT','oneday',15,20),
('WO.TT','oneday',16,15),
('WO.TT','oneday',17,10),
('WO.TT','oneday',18,10),
('WO.TT','oneday',19,5),
('WO.TT','oneday',20,5),
('WO.TT','oneday',21,3),
('WO.TT','oneday',22,3),
('WO.TT','oneday',23,3),
('WO.TT','oneday',24,3),
('WO.TT','oneday',25,3),
('WO.TT','gc',1,455),
('WO.TT','gc',2,325),
('WO.TT','gc',3,260),
('WO.TT','gc',4,195),
('WO.TT','gc',5,165),
('WO.TT','gc',6,130),
('WO.TT','gc',7,110),
('WO.TT','gc',8,90),
('WO.TT','gc',9,80),
('WO.TT','gc',10,65),
('WO.TT','gc',11,55),
('WO.TT','gc',12,40),
('WO.TT','gc',13,30),
('WO.TT','gc',14,25),
('WO.TT','gc',15,20),
('WO.TT','gc',16,15),
('WO.TT','gc',17,10),
('WO.TT','gc',18,10),
('WO.TT','gc',19,5),
('WO.TT','gc',20,5),
('WO.TT','gc',21,3),
('WO.TT','gc',22,3),
('WO.TT','gc',23,3),
('WO.TT','gc',24,3),
('WO.TT','gc',25,3),
('C1','oneday',1,500),
('C1','oneday',2,400),
('C1','oneday',3,325),
('C1','oneday',4,275),
('C1','oneday',5,225),
('C1','oneday',6,175),
('C1','oneday',7,150),
('C1','oneday',8,125),
('C1','oneday',9,100),
('C1','oneday',10,85),
('C1','oneday',11,70),
('C1','oneday',12,60),
('C1','oneday',13,50),
('C1','oneday',14,40),
('C1','oneday',15,35),
('C1','oneday',16,30),
('C1','oneday',17,30),
('C1','oneday',18,30),
('C1','oneday',19,30),
('C1','oneday',20,30),
('C1','oneday',21,20),
('C1','oneday',22,20),
('C1','oneday',23,20),
('C1','oneday',24,20),
('C1','oneday',25,20),
('C1','oneday',26,20),
('C1','oneday',27,20),
('C1','oneday',28,20),
('C1','oneday',29,20),
('C1','oneday',30,20),
('C1','oneday',31,10),
('C1','oneday',32,10),
('C1','oneday',33,10),
('C1','oneday',34,10),
('C1','oneday',35,10),
('C1','oneday',36,10),
('C1','oneday',37,10),
('C1','oneday',38,10),
('C1','oneday',39,10),
('C1','oneday',40,10),
('C1','oneday',41,10),
('C1','oneday',42,10),
('C1','oneday',43,10),
('C1','oneday',44,10),
('C1','oneday',45,10),
('C1','oneday',46,10),
('C1','oneday',47,10),
('C1','oneday',48,10),
('C1','oneday',49,10),
('C1','oneday',50,10),
('C1','oneday',51,5),
('C1','oneday',52,5),
('C1','oneday',53,5),
('C1','oneday',54,5),
('C1','oneday',55,5),
('C1','oneday',56,3),
('C1','oneday',57,3),
('C1','oneday',58,3),
('C1','oneday',59,3),
('C1','oneday',60,3),
('C1','gc',1,500),
('C1','gc',2,400),
('C1','gc',3,325),
('C1','gc',4,275),
('C1','gc',5,225),
('C1','gc',6,175),
('C1','gc',7,150),
('C1','gc',8,125),
('C1','gc',9,100),
('C1','gc',10,85),
('C1','gc',11,70),
('C1','gc',12,60),
('C1','gc',13,50),
('C1','gc',14,40),
('C1','gc',15,35),
('C1','gc',16,30),
('C1','gc',17,30),
('C1','gc',18,30),
('C1','gc',19,30),
('C1','gc',20,30),
('C1','gc',21,20),
('C1','gc',22,20),
('C1','gc',23,20),
('C1','gc',24,20),
('C1','gc',25,20),
('C1','gc',26,20),
('C1','gc',27,20),
('C1','gc',28,20),
('C1','gc',29,20),
('C1','gc',30,20),
('C1','gc',31,10),
('C1','gc',32,10),
('C1','gc',33,10),
('C1','gc',34,10),
('C1','gc',35,10),
('C1','gc',36,10),
('C1','gc',37,10),
('C1','gc',38,10),
('C1','gc',39,10),
('C1','gc',40,10),
('C1','gc',41,10),
('C1','gc',42,10),
('C1','gc',43,10),
('C1','gc',44,10),
('C1','gc',45,10),
('C1','gc',46,10),
('C1','gc',47,10),
('C1','gc',48,10),
('C1','gc',49,10),
('C1','gc',50,10),
('C1','gc',51,5),
('C1','gc',52,5),
('C1','gc',53,5),
('C1','gc',54,5),
('C1','gc',55,5),
('C1','gc',56,3),
('C1','gc',57,3),
('C1','gc',58,3),
('C1','gc',59,3),
('C1','gc',60,3),
('C1','stage',1,60),
('C1','stage',2,40),
('C1','stage',3,30),
('C1','stage',4,25),
('C1','stage',5,20),
('C1','stage',6,15),
('C1','stage',7,10),
('C1','stage',8,8),
('C1','stage',9,5),
('C1','stage',10,2),
('C1','leader',1,10),
('C2','oneday',1,400),
('C2','oneday',2,320),
('C2','oneday',3,260),
('C2','oneday',4,220),
('C2','oneday',5,180),
('C2','oneday',6,140),
('C2','oneday',7,120),
('C2','oneday',8,100),
('C2','oneday',9,80),
('C2','oneday',10,68),
('C2','oneday',11,56),
('C2','oneday',12,48),
('C2','oneday',13,40),
('C2','oneday',14,32),
('C2','oneday',15,28),
('C2','oneday',16,24),
('C2','oneday',17,24),
('C2','oneday',18,24),
('C2','oneday',19,24),
('C2','oneday',20,24),
('C2','oneday',21,16),
('C2','oneday',22,16),
('C2','oneday',23,16),
('C2','oneday',24,16),
('C2','oneday',25,16),
('C2','oneday',26,16),
('C2','oneday',27,16),
('C2','oneday',28,16),
('C2','oneday',29,16),
('C2','oneday',30,16),
('C2','oneday',31,8),
('C2','oneday',32,8),
('C2','oneday',33,8),
('C2','oneday',34,8),
('C2','oneday',35,8),
('C2','oneday',36,8),
('C2','oneday',37,8),
('C2','oneday',38,8),
('C2','oneday',39,8),
('C2','oneday',40,8),
('C2','oneday',41,8),
('C2','oneday',42,8),
('C2','oneday',43,8),
('C2','oneday',44,8),
('C2','oneday',45,8),
('C2','oneday',46,8),
('C2','oneday',47,8),
('C2','oneday',48,8),
('C2','oneday',49,8),
('C2','oneday',50,8),
('C2','oneday',51,4),
('C2','oneday',52,4),
('C2','oneday',53,4),
('C2','oneday',54,4),
('C2','oneday',55,4),
('C2','oneday',56,2),
('C2','oneday',57,2),
('C2','oneday',58,2),
('C2','oneday',59,2),
('C2','oneday',60,2),
('C2','gc',1,400),
('C2','gc',2,320),
('C2','gc',3,260),
('C2','gc',4,220),
('C2','gc',5,180),
('C2','gc',6,140),
('C2','gc',7,120),
('C2','gc',8,100),
('C2','gc',9,80),
('C2','gc',10,68),
('C2','gc',11,56),
('C2','gc',12,48),
('C2','gc',13,40),
('C2','gc',14,32),
('C2','gc',15,28),
('C2','gc',16,24),
('C2','gc',17,24),
('C2','gc',18,24),
('C2','gc',19,24),
('C2','gc',20,24),
('C2','gc',21,16),
('C2','gc',22,16),
('C2','gc',23,16),
('C2','gc',24,16),
('C2','gc',25,16),
('C2','gc',26,16),
('C2','gc',27,16),
('C2','gc',28,16),
('C2','gc',29,16),
('C2','gc',30,16),
('C2','gc',31,8),
('C2','gc',32,8),
('C2','gc',33,8),
('C2','gc',34,8),
('C2','gc',35,8),
('C2','gc',36,8),
('C2','gc',37,8),
('C2','gc',38,8),
('C2','gc',39,8),
('C2','gc',40,8),
('C2','gc',41,8),
('C2','gc',42,8),
('C2','gc',43,8),
('C2','gc',44,8),
('C2','gc',45,8),
('C2','gc',46,8),
('C2','gc',47,8),
('C2','gc',48,8),
('C2','gc',49,8),
('C2','gc',50,8),
('C2','gc',51,4),
('C2','gc',52,4),
('C2','gc',53,4),
('C2','gc',54,4),
('C2','gc',55,4),
('C2','gc',56,2),
('C2','gc',57,2),
('C2','gc',58,2),
('C2','gc',59,2),
('C2','gc',60,2),
('C2','stage',1,50),
('C2','stage',2,30),
('C2','stage',3,25),
('C2','stage',4,20),
('C2','stage',5,15),
('C2','stage',6,10),
('C2','stage',7,8),
('C2','stage',8,6),
('C2','stage',9,3),
('C2','stage',10,1),
('C2','leader',1,8),
('CC','oneday',1,250),
('CC','oneday',2,200),
('CC','oneday',3,150),
('CC','oneday',4,125),
('CC','oneday',5,100),
('CC','oneday',6,90),
('CC','oneday',7,80),
('CC','oneday',8,70),
('CC','oneday',9,60),
('CC','oneday',10,50),
('CC','oneday',11,40),
('CC','oneday',12,35),
('CC','oneday',13,30),
('CC','oneday',14,25),
('CC','oneday',15,20),
('CC','oneday',16,15),
('CC','oneday',17,10),
('CC','oneday',18,5),
('CC','oneday',19,5),
('CC','oneday',20,5),
('CC','oneday',21,5),
('CC','oneday',22,5),
('CC','oneday',23,5),
('CC','oneday',24,5),
('CC','oneday',25,5),
('CC','oneday',26,5),
('CC','oneday',27,5),
('CC','oneday',28,5),
('CC','oneday',29,5),
('CC','oneday',30,5),
('CC','oneday',31,3),
('CC','oneday',32,3),
('CC','oneday',33,3),
('CC','oneday',34,3),
('CC','oneday',35,3),
('CC','oneday',36,1),
('CC','oneday',37,1),
('CC','oneday',38,1),
('CC','oneday',39,1),
('CC','oneday',40,1),
('CC','gc',1,250),
('CC','gc',2,200),
('CC','gc',3,150),
('CC','gc',4,125),
('CC','gc',5,100),
('CC','gc',6,90),
('CC','gc',7,80),
('CC','gc',8,70),
('CC','gc',9,60),
('CC','gc',10,50),
('CC','gc',11,40),
('CC','gc',12,35),
('CC','gc',13,30),
('CC','gc',14,25),
('CC','gc',15,20),
('CC','gc',16,15),
('CC','gc',17,10),
('CC','gc',18,5),
('CC','gc',19,5),
('CC','gc',20,5),
('CC','gc',21,5),
('CC','gc',22,5),
('CC','gc',23,5),
('CC','gc',24,5),
('CC','gc',25,5),
('CC','gc',26,5),
('CC','gc',27,5),
('CC','gc',28,5),
('CC','gc',29,5),
('CC','gc',30,5),
('CC','gc',31,3),
('CC','gc',32,3),
('CC','gc',33,3),
('CC','gc',34,3),
('CC','gc',35,3),
('CC','gc',36,1),
('CC','gc',37,1),
('CC','gc',38,1),
('CC','gc',39,1),
('CC','gc',40,1),
('CC.TT','oneday',1,70),
('CC.TT','oneday',2,55),
('CC.TT','oneday',3,40),
('CC.TT','oneday',4,30),
('CC.TT','oneday',5,25),
('CC.TT','oneday',6,20),
('CC.TT','oneday',7,15),
('CC.TT','oneday',8,10),
('CC.TT','oneday',9,5),
('CC.TT','oneday',10,3),
('CC.TT','gc',1,70),
('CC.TT','gc',2,55),
('CC.TT','gc',3,40),
('CC.TT','gc',4,30),
('CC.TT','gc',5,25),
('CC.TT','gc',6,20),
('CC.TT','gc',7,15),
('CC.TT','gc',8,10),
('CC.TT','gc',9,5),
('CC.TT','gc',10,3),
('NC','oneday',1,100),
('NC','oneday',2,75),
('NC','oneday',3,60),
('NC','oneday',4,50),
('NC','oneday',5,40),
('NC','oneday',6,30),
('NC','oneday',7,20),
('NC','oneday',8,10),
('NC','oneday',9,5),
('NC','oneday',10,3),
('NC','oneday',11,3),
('NC','oneday',12,1),
('NC','oneday',13,1),
('NC','oneday',14,1),
('NC','oneday',15,1),
('NC','gc',1,100),
('NC','gc',2,75),
('NC','gc',3,60),
('NC','gc',4,50),
('NC','gc',5,40),
('NC','gc',6,30),
('NC','gc',7,20),
('NC','gc',8,10),
('NC','gc',9,5),
('NC','gc',10,3),
('NC','gc',11,3),
('NC','gc',12,1),
('NC','gc',13,1),
('NC','gc',14,1),
('NC','gc',15,1),
('NC.TT','oneday',1,50),
('NC.TT','oneday',2,30),
('NC.TT','oneday',3,20),
('NC.TT','oneday',4,15),
('NC.TT','oneday',5,10),
('NC.TT','oneday',6,5),
('NC.TT','oneday',7,3),
('NC.TT','oneday',8,3),
('NC.TT','oneday',9,1),
('NC.TT','oneday',10,1),
('NC.TT','gc',1,50),
('NC.TT','gc',2,30),
('NC.TT','gc',3,20),
('NC.TT','gc',4,15),
('NC.TT','gc',5,10),
('NC.TT','gc',6,5),
('NC.TT','gc',7,3),
('NC.TT','gc',8,3),
('NC.TT','gc',9,1),
('NC.TT','gc',10,1),
('Pro','oneday',1,250),
('Pro','oneday',2,170),
('Pro','oneday',3,140),
('Pro','oneday',4,120),
('Pro','oneday',5,100),
('Pro','oneday',6,80),
('Pro','oneday',7,70),
('Pro','oneday',8,60),
('Pro','oneday',9,50),
('Pro','oneday',10,40),
('Pro','oneday',11,30),
('Pro','oneday',12,20),
('Pro','oneday',13,10),
('Pro','oneday',14,10),
('Pro','oneday',15,10),
('Pro','oneday',16,6),
('Pro','oneday',17,6),
('Pro','oneday',18,6),
('Pro','oneday',19,6),
('Pro','oneday',20,6),
('Pro','oneday',21,6),
('Pro','oneday',22,6),
('Pro','oneday',23,6),
('Pro','oneday',24,6),
('Pro','oneday',25,6),
('Pro','oneday',26,5),
('Pro','oneday',27,5),
('Pro','oneday',28,5),
('Pro','oneday',29,5),
('Pro','oneday',30,5),
('Pro','oneday',31,3),
('Pro','oneday',32,3),
('Pro','oneday',33,3),
('Pro','oneday',34,3),
('Pro','oneday',35,3),
('Pro','oneday',36,3),
('Pro','oneday',37,3),
('Pro','oneday',38,3),
('Pro','oneday',39,3),
('Pro','oneday',40,3),
('Pro','gc',1,250),
('Pro','gc',2,170),
('Pro','gc',3,140),
('Pro','gc',4,120),
('Pro','gc',5,100),
('Pro','gc',6,80),
('Pro','gc',7,70),
('Pro','gc',8,60),
('Pro','gc',9,50),
('Pro','gc',10,40),
('Pro','gc',11,30),
('Pro','gc',12,20),
('Pro','gc',13,10),
('Pro','gc',14,10),
('Pro','gc',15,10),
('Pro','gc',16,6),
('Pro','gc',17,6),
('Pro','gc',18,6),
('Pro','gc',19,6),
('Pro','gc',20,6),
('Pro','gc',21,6),
('Pro','gc',22,6),
('Pro','gc',23,6),
('Pro','gc',24,6),
('Pro','gc',25,6),
('Pro','gc',26,5),
('Pro','gc',27,5),
('Pro','gc',28,5),
('Pro','gc',29,5),
('Pro','gc',30,5),
('Pro','gc',31,3),
('Pro','gc',32,3),
('Pro','gc',33,3),
('Pro','gc',34,3),
('Pro','gc',35,3),
('Pro','gc',36,3),
('Pro','gc',37,3),
('Pro','gc',38,3),
('Pro','gc',39,3),
('Pro','gc',40,3),
('Pro','stage',1,25),
('Pro','stage',2,15),
('Pro','stage',3,10),
('Pro','stage',4,5),
('Pro','stage',5,3),
('Pro','leader',1,5),
('1','oneday',1,125),
('1','oneday',2,85),
('1','oneday',3,70),
('1','oneday',4,60),
('1','oneday',5,50),
('1','oneday',6,40),
('1','oneday',7,35),
('1','oneday',8,30),
('1','oneday',9,25),
('1','oneday',10,20),
('1','oneday',11,15),
('1','oneday',12,10),
('1','oneday',13,5),
('1','oneday',14,5),
('1','oneday',15,5),
('1','oneday',16,3),
('1','oneday',17,3),
('1','oneday',18,3),
('1','oneday',19,3),
('1','oneday',20,3),
('1','oneday',21,3),
('1','oneday',22,3),
('1','oneday',23,3),
('1','oneday',24,3),
('1','oneday',25,3),
('1','gc',1,125),
('1','gc',2,85),
('1','gc',3,70),
('1','gc',4,60),
('1','gc',5,50),
('1','gc',6,40),
('1','gc',7,35),
('1','gc',8,30),
('1','gc',9,25),
('1','gc',10,20),
('1','gc',11,15),
('1','gc',12,10),
('1','gc',13,5),
('1','gc',14,5),
('1','gc',15,5),
('1','gc',16,3),
('1','gc',17,3),
('1','gc',18,3),
('1','gc',19,3),
('1','gc',20,3),
('1','gc',21,3),
('1','gc',22,3),
('1','gc',23,3),
('1','gc',24,3),
('1','gc',25,3),
('1','stage',1,14),
('1','stage',2,5),
('1','stage',3,3),
('1','leader',1,3);

-- Grupo de puntuación de una carrera en cada sistema
create or replace function public.scoring_group(p_scheme text, p_category text, p_slug text) returns text
language sql immutable as $fn$
  select case p_scheme
    when 'cyc' then p_category
    when 'cyc_wt' then case when p_category in ('MWT', 'SWT') then 'WT' else p_category end
    else case p_category
      when 'TDF' then 'GT.A' when 'GT' then 'GT.B' when 'MON' then 'Monument'
      when 'WC' then 'WO' when 'WC_ITT' then 'WO.TT' when 'CC' then 'CC' when 'CC_ITT' then 'CC.TT'
      when 'NC' then 'NC' when 'NC_ITT' then 'NC.TT' when 'PRO' then 'Pro' when 'C1' then '1'
      when 'MWT' then case when p_slug ~ '^(tour-down-under|uae-tour|strade-bianche|paris-nice|tirreno-adriatico|gent-wevelgem|amstel-gold-race|la-fleche-wallonne|fleche-wallonne|dauphine|tour-auvergne-rhone-alpes|tour-de-romandie|tour-de-suisse|gp-quebec|gp-montreal)' then 'C1' else 'C2' end
      when 'SWT' then case when p_slug ~ '^(tour-down-under|uae-tour|strade-bianche|paris-nice|tirreno-adriatico|gent-wevelgem|amstel-gold-race|la-fleche-wallonne|fleche-wallonne|dauphine|tour-auvergne-rhone-alpes|tour-de-romandie|tour-de-suisse|gp-quebec|gp-montreal)' then 'C1' else 'C2' end
    end end
$fn$;

-- Todas las tablas de puntos, por sistema y grupo
create or replace view public.scoring_points as
  select 'cyc'::text as scheme, category as grp, kind, position, points from public.scoring_rule where category <> 'WT'
  union all
  select 'cyc_wt', category, kind, position, points from public.scoring_rule where category not in ('MWT', 'SWT')
  union all
  select 'uci', grp, kind, position, points from public.uci_rule;

-- Sistema de una liga
create or replace function public.league_scheme_of(lg public.league) returns text
language sql immutable as $fn$
  select case when lg.scoring_system = 'uci' then 'uci' when lg.wt_split then 'cyc' else 'cyc_wt' end
$fn$;
create or replace function public.league_scheme(p_league uuid) returns text
language sql stable security definer set search_path = public as $fn$
  select public.league_scheme_of(l) from public.league l where l.id = p_league
$fn$;

-- ---------------------------------------------------------------- puntos de cada ciclista, por sistema
alter table public.rider_score add column if not exists scheme text not null default 'cyc';
alter table public.rider_score drop constraint if exists rider_score_pkey;
alter table public.rider_score add primary key (stage_id, rider_id, scheme, kind);

create or replace function public.score_stage(p_stage bigint) returns integer
language plpgsql as $$
declare
  s public.stage;
  rc public.race;
  is_last boolean;
  n integer;
begin
  select * into s from public.stage where id = p_stage;
  if not found then raise exception 'Etapa % no existe', p_stage; end if;
  select * into rc from public.race where id = s.race_id;
  is_last := s.number = (select max(number) from public.stage where race_id = s.race_id);

  delete from public.member_score where stage_id = p_stage;
  delete from public.rider_score where stage_id = p_stage;

  -- puntos de cada ciclista en cada sistema: Cyclonomy ('cyc', WT en A y B; 'cyc_wt', WT junto) y UCI ('uci')
  insert into public.rider_score (stage_id, rider_id, scheme, kind, points)
  select p_stage, r.rider_id, sch.scheme, x.score_kind, sum(sp.points)
  from public.result r
  cross join (values ('cyc'), ('cyc_wt'), ('uci')) as sch(scheme)
  join (values
          -- resultado, puntuación, solo en la última etapa, en vueltas (true) o en clásicas (false)
          ('stage', 'oneday', false, false), ('stage', 'stage', false, true),
          ('kom_leader', 'kom_jersey', false, true), ('gc', 'leader', false, true),
          ('gc', 'gc', true, true), ('points', 'points_final', true, true), ('kom', 'kom_final', true, true))
       as x(result_kind, score_kind, only_last, stage_race) on x.result_kind = r.kind and x.stage_race = rc.is_stage_race
  join public.scoring_points sp on sp.scheme = sch.scheme
                                and sp.grp = public.scoring_group(sch.scheme, rc.category, rc.pcs_slug)
                                and sp.kind = x.score_kind and sp.position = r.position
  where r.stage_id = p_stage and (not x.only_last or is_last)
  group by r.rider_id, sch.scheme, x.score_kind;
  get diagnostics n = row_count;

  -- Puntos de cada jugador, con el sistema de su liga: ciclistas inscritos, ligas cuya profundidad incluye la
  -- carrera, y solo si el jugador no está sancionado por deuda esa semana
  insert into public.member_score (league_id, member_id, stage_id, rider_id, points)
  select e.league_id, e.member_id, p_stage, rs.rider_id, sum(rs.points)
  from public.race_entry e
  join public.league lg on lg.id = e.league_id
  join public.race_category c on c.code = rc.category and c.depth_level <= lg.calendar_depth
  join public.race_entry_rider er on er.entry_id = e.id
  join public.rider_score rs on rs.rider_id = er.rider_id and rs.stage_id = p_stage
                            and rs.scheme = public.league_scheme_of(lg)
  left join public.member_week mw on mw.member_id = e.member_id
                                 and mw.week_start = date_trunc('week', s.date)::date
  where e.race_id = rc.id and coalesce(mw.eligible, true)
  group by e.league_id, e.member_id, rs.rider_id;

  update public.stage set status = 'scored', scored_at = public.app_now() where id = p_stage;
  return n;
end $$;

create or replace function public.get_race_detail(p_league uuid, p_race bigint) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me public.league_member := public.my_member(p_league);
  v_scheme text := public.league_scheme(p_league);
  rc public.race;
  v_last bigint;
  v_kind text;
begin
  select * into rc from public.race where id = p_race;
  select s.id into v_last from public.stage s where s.race_id = p_race and s.status = 'scored'
  order by s.number desc limit 1;
  v_kind := case when rc.is_stage_race then 'gc' else 'stage' end;

  return jsonb_build_object(
    'stages', coalesce((
      select jsonb_agg(jsonb_build_object(
               'stage_id', s.id, 'number', s.number, 'date', s.date, 'status', s.status,
               'distance_km', s.distance_km, 'vertical_m', s.vertical_m,
               'my_points', (select coalesce(sum(points), 0) from public.member_score
                             where stage_id = s.id and member_id = me.id),
               'my_final_points', (select coalesce(sum(rs.points), 0) from public.member_score ms
                                   join public.rider_score rs on rs.stage_id = ms.stage_id and rs.rider_id = ms.rider_id
                                                              and rs.scheme = v_scheme
                                   where ms.stage_id = s.id and ms.member_id = me.id
                                     and rs.kind in ('gc', 'points_final', 'kom_final')),
               'top_member', (select jsonb_build_object('team_name', m.team_name, 'points', sum(ms.points))
                              from public.member_score ms join public.league_member m on m.id = ms.member_id
                              where ms.stage_id = s.id and ms.league_id = p_league
                              group by m.id, m.team_name order by sum(ms.points) desc limit 1),
               -- ganador: de la clasificación completa si existe; si no (carreras antiguas), de los del juego
               'winner', coalesce(
                 (select jsonb_build_object(
                           'name', coalesce(rd.name, sl.rider_name, initcap(replace(f.rider_slug, '-', ' '))),
                           'nationality', coalesce(rd.nationality, sl.nationality),
                           'team', coalesce(sl.team_name, tm.name))
                  from public.result_full f
                  left join public.rider rd on rd.id = f.rider_id
                  left join public.team tm on tm.id = rd.team_id
                  left join public.startlist_rider sl on sl.race_id = p_race and sl.rider_slug = f.rider_slug
                  where f.stage_id = s.id and f.kind = 'stage' and f.position = 1 limit 1),
                 (select jsonb_build_object('name', rd.name, 'nationality', rd.nationality,
                                            'team', coalesce(sl.team_name, tm.name))
                  from public.result r join public.rider rd on rd.id = r.rider_id
                  left join public.team tm on tm.id = rd.team_id
                  left join public.startlist_rider sl on sl.race_id = p_race and sl.rider_id = rd.id
                  where r.stage_id = s.id and r.kind = 'stage' and r.position = 1 limit 1)))
             order by s.number)
      from public.stage s where s.race_id = p_race), '[]'::jsonb),
    'league_total', coalesce((
      select jsonb_agg(jsonb_build_object('member_id', x.member_id, 'team_name', m.team_name, 'points', x.pts,
                                          'country', m.country)
                       order by x.pts desc)
      from (select ms.member_id, sum(ms.points)::int pts from public.member_score ms
            join public.stage s on s.id = ms.stage_id
            where s.race_id = p_race and ms.league_id = p_league group by ms.member_id) x
      join public.league_member m on m.id = x.member_id), '[]'::jsonb),
    'gc', coalesce((
      select jsonb_agg(jsonb_build_object(
               'position', g.position, 'rider_id', g.rider_id, 'name', g.name, 'nationality', g.nationality,
               'team', g.team,
               'in_game', g.rider_id is not null,
               'scored_for', coalesce((
                 select jsonb_agg(x.team_name order by x.team_name)
                 from (select distinct lm.team_name from public.member_score ms
                       join public.stage s2 on s2.id = ms.stage_id
                       join public.league_member lm on lm.id = ms.member_id
                       where s2.race_id = p_race and ms.league_id = p_league
                         and ms.rider_id = g.rider_id and ms.points > 0) x), '[]'::jsonb))
             order by g.position)
      from (
        -- clasificación completa si existe; si no (carreras antiguas), solo los del juego
        select f.position, f.rider_id,
               coalesce(rd.name, sl.rider_name, initcap(replace(f.rider_slug, '-', ' '))) as name,
               coalesce(rd.nationality, sl.nationality) as nationality,
               coalesce(sl.team_name, tm.name) as team
        from public.result_full f
        left join public.rider rd on rd.id = f.rider_id
        left join public.team tm on tm.id = rd.team_id
        left join public.startlist_rider sl on sl.race_id = p_race and sl.rider_slug = f.rider_slug
        where f.stage_id = v_last and f.kind = v_kind and f.position <= 10
        union all
        select r.position, rd.id, rd.name, rd.nationality, tm.name
        from public.result r join public.rider rd on rd.id = r.rider_id
        left join public.team tm on tm.id = rd.team_id
        where r.stage_id = v_last and r.kind = v_kind and r.position <= 10
          and not exists (select 1 from public.result_full f where f.stage_id = v_last)
      ) g), '[]'::jsonb));
end $$;

create or replace function public.get_stage_scores(p_league uuid, p_stage bigint, p_part text default null) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me public.league_member := public.my_member(p_league);
  v_scheme text := public.league_scheme(p_league);
  -- 'stage': lo de la propia etapa; 'final': las clasificaciones finales (general, regularidad, montaña); null: todo
  v_kinds text[] := case p_part when 'stage' then array['stage', 'oneday', 'kom_jersey', 'leader']
                                when 'final' then array['gc', 'points_final', 'kom_final']
                                else array['stage', 'oneday', 'kom_jersey', 'leader', 'gc', 'points_final', 'kom_final'] end;
begin
  return jsonb_build_object(
    'stage', (select jsonb_build_object('id', s.id, 'number', s.number, 'date', s.date, 'status', s.status,
                                        'race_id', rc.id, 'race_name', rc.name, 'is_stage_race', rc.is_stage_race,
                                        'country', rc.country)
              from public.stage s join public.race rc on rc.id = s.race_id where s.id = p_stage),
    'members', coalesce((
      select jsonb_agg(jsonb_build_object('member_id', m.id, 'team_name', m.team_name, 'points', x.pts,
                                          'is_mine', m.id = me.id, 'country', m.country,
                                          -- sus ciclistas inscritos en la carrera y lo que ha puntuado cada uno
                                          -- (las inscripciones de los demás solo se ven al cerrar la inscripción)
                                          'riders', coalesce((
                                            select jsonb_agg(jsonb_build_object('rider_id', r.id, 'name', r.name,
                                                                                'points', rp.pts)
                                                             order by rp.pts desc, r.market_value desc)
                                            from public.stage s
                                            join public.race rc on rc.id = s.race_id
                                            join public.race_entry e on e.race_id = rc.id and e.member_id = m.id
                                            join public.race_entry_rider er on er.entry_id = e.id
                                            join public.rider r on r.id = er.rider_id
                                            left join public.member_score ms on ms.stage_id = p_stage
                                                 and ms.member_id = m.id and ms.rider_id = r.id
                                            -- lo que puntuó para el jugador (solo si le contaba: hay member_score)
                                            cross join lateral (
                                              select coalesce(sum(rs.points), 0)::int pts from public.rider_score rs
                                              where ms.member_id is not null and rs.stage_id = p_stage
                                                and rs.rider_id = r.id and rs.kind = any(v_kinds) and rs.scheme = v_scheme) rp
                                            where s.id = p_stage
                                              and (m.id = me.id or public.app_now() >= rc.entries_close_at)), '[]'::jsonb))
                       order by x.pts desc, m.team_name)
      from public.league_member m
      cross join lateral (select coalesce(sum(rs.points), 0)::int pts from public.member_score ms
                          join public.rider_score rs on rs.stage_id = ms.stage_id and rs.rider_id = ms.rider_id
                          where ms.stage_id = p_stage and ms.member_id = m.id and rs.kind = any(v_kinds)
                            and rs.scheme = v_scheme) x
      where m.league_id = p_league), '[]'::jsonb),
    'riders', coalesce((
      select jsonb_agg(jsonb_build_object('rider_id', r.id, 'name', r.name, 'points', x.pts, 'owner', own.team_name,
                                          'pro_team', t.name, 'nationality', r.nationality, 'photo_url', r.photo_url,
                                          'entered_by', coalesce((
                                            select jsonb_agg(lm.team_name order by lm.team_name)
                                            from public.member_score ms2 join public.league_member lm on lm.id = ms2.member_id
                                            where ms2.stage_id = p_stage and ms2.league_id = p_league
                                              and ms2.rider_id = r.id), '[]'::jsonb),
                                          'entered_by_me', exists (
                                            select 1 from public.member_score ms2
                                            where ms2.stage_id = p_stage and ms2.member_id = me.id
                                              and ms2.rider_id = r.id))
                       order by x.pts desc)
      from (select rs.rider_id, sum(rs.points)::int pts from public.rider_score rs
            where rs.stage_id = p_stage and rs.kind = any(v_kinds) and rs.scheme = v_scheme
            group by rs.rider_id) x
      join public.rider r on r.id = x.rider_id
      left join public.team t on t.id = r.team_id
      left join lateral (select lm.team_name from public.ownership o join public.league_member lm on lm.id = o.member_id
                         where o.league_id = p_league and o.rider_id = r.id) own on true), '[]'::jsonb));
end $$;

create or replace function public.get_rider(p_league uuid, p_rider bigint) returns jsonb
language plpgsql stable security definer set search_path = public as $$
declare
  me public.league_member := public.my_member(p_league);
  v_scheme text := public.league_scheme(p_league);
  v_season integer := extract(year from public.app_now() at time zone 'Europe/Madrid');
  v_today date := (public.app_now() at time zone 'Europe/Madrid')::date;
begin
  if not exists (select 1 from public.rider where id = p_rider) then
    raise exception 'El ciclista no existe';
  end if;
  return jsonb_build_object(
    'rider', (select jsonb_build_object(
                'id', r.id, 'name', r.name, 'pro_team', t.name, 'nationality', r.nationality,
                'age', public.age_at(r.birthdate)::int, 'market_value', r.market_value,
                'season_points', coalesce((select sp.points from public.rider_season_points sp
                                           where sp.rider_id = r.id and sp.season = v_season), 0),
                'photo', case when r.photo_url is null then null else jsonb_build_object(
                           'url', r.photo_url, 'author', r.photo_author, 'license', r.photo_license,
                           'license_url', r.photo_license_url, 'page_url', r.photo_page_url) end)
              from public.rider r left join public.team t on t.id = r.team_id where r.id = p_rider),
    'owner', (select jsonb_build_object('member_id', m.id, 'team_name', m.team_name, 'is_mine', m.id = me.id,
                                        'clause', o.clause)
              from public.ownership o join public.league_member m on m.id = o.member_id
              where o.league_id = p_league and o.rider_id = p_rider),
    'values', coalesce((
      select jsonb_agg(jsonb_build_object('day', h.day, 'value', h.value) order by h.day)
      from public.rider_value_history h
      where h.rider_id = p_rider and h.day > v_today - 365), '[]'::jsonb),
    'results', coalesce((
      select jsonb_agg(jsonb_build_object(
               'stage_id', x.stage_id, 'race_key', x.race_key, 'race_start', x.race_start, 'race_end', x.race_end,
               'race_name', x.race_name, 'country', x.country, 'category', x.category,
               'is_stage_race', x.is_stage_race, 'number', x.number, 'date', x.date, 'kind', x.kind,
               'position', x.position, 'points', x.points)
             order by x.date desc, x.kind_order)
      from (
        -- resultados del juego
        (select s.id stage_id, 'g' || rc.id race_key, rc.start_date race_start, rc.end_date race_end, rc.name race_name, rc.country, rc.category, rc.is_stage_race, s.number, s.date,
                res.kind, res.position,
                case res.kind when 'stage' then 0 when 'gc' then 1 when 'points' then 2 else 3 end kind_order,
                coalesce((select sum(rs.points)::int from public.rider_score rs
                          where rs.stage_id = s.id and rs.rider_id = p_rider and rs.scheme = v_scheme
                            and rs.kind = case res.kind when 'stage' then (case when rc.is_stage_race then 'stage' else 'oneday' end)
                                                        when 'gc' then 'gc' when 'points' then 'points_final'
                                                        else 'kom_final' end), 0) points
         from public.result res
         join public.stage s on s.id = res.stage_id
         join public.race rc on rc.id = s.race_id
         where res.rider_id = p_rider
           and (res.kind = 'stage'
                or (rc.is_stage_race and res.kind in ('gc', 'points', 'kom')
                    and s.number = (select max(s2.number) from public.stage s2 where s2.race_id = rc.id))))
        union all
        -- historial: los puntos son los que daría la tabla de puntuación de la liga
        (select null::bigint, 'h' || h.season || '-' || h.race_slug,
                min(h.date) over (partition by h.season, h.race_slug), max(h.date) over (partition by h.season, h.race_slug),
                h.race_name, h.country, h.category, h.is_stage_race, h.number, h.date, h.kind, h.position,
                case h.kind when 'stage' then 0 when 'gc' then 1 when 'points' then 2 else 3 end,
                coalesce((select sr.points from public.scoring_points sr
                          where sr.scheme = v_scheme and sr.grp = public.scoring_group(v_scheme, h.category, h.race_slug)
                            and sr.position = h.position
                            and sr.kind = case h.kind when 'stage' then (case when h.is_stage_race then 'stage' else 'oneday' end)
                                                      when 'gc' then 'gc' when 'points' then 'points_final'
                                                      else 'kom_final' end), 0)
         from public.rider_history_result h
         where h.rider_id = p_rider
           -- si la carrera también está en el calendario del juego, valen sus resultados (no se repiten)
           and not exists (select 1 from public.race g where g.pcs_slug = h.race_slug and g.season = h.season))
        order by 10 desc
        limit 600) x), '[]'::jsonb));
end $$;

create or replace function public.update_rider_values() returns integer
language plpgsql as $$
declare
  vp public.value_params;
  today date := (public.app_now() at time zone 'Europe/Madrid')::date;
  base_w numeric;
  n_leagues integer;
  n integer;
begin
  select * into vp from public.value_params;
  -- peso de los puntos PCS base: 1 antes de empezar el juego, baja a 0 en 365 días
  base_w := greatest(0, 1 - greatest(0, today - vp.game_start)::numeric / 365);
  select greatest(count(*), 1) into n_leagues from public.league;

  with pts as (
    select rs.rider_id, sum(rs.points) as p
    from public.rider_score rs join public.stage s on s.id = rs.stage_id
    where s.date > today - 365 and s.date <= today and rs.scheme = 'cyc'   -- el valor, con la tabla de Cyclonomy
    group by rs.rider_id
  ), hype as (
    select l.rider_id,
           sum(case l.kind when 'market_buy' then 1 when 'clause_paid' then 2 when 'sale_game' then -1 end)::numeric as h
    from public.ledger l
    where l.created_at > public.app_now() - interval '7 days'
      and l.kind in ('market_buy', 'clause_paid', 'sale_game') and l.rider_id is not null
    group by l.rider_id
  ), calc as (
    select r.id, r.market_value::numeric as v,
           public.value_from_points(coalesce(pts.p, 0) + r.pcs_points_base * base_w,
                                    public.age_at(r.birthdate, today), vp.daily_round)::numeric as target,
           greatest(-vp.hype_cap, least(vp.hype_cap, coalesce(hype.h, 0) / n_leagues * vp.hype_scale)) as hype_pct
    from public.rider r
    left join pts on pts.rider_id = r.id
    left join hype on hype.rider_id = r.id
    where r.active
  )
  update public.rider r
     set market_value = greatest(vp.floor_value,
           round((c.v + greatest(-vp.daily_cap * c.v,
                                 least(vp.daily_cap * c.v, vp.reversion * (c.target - c.v) + c.hype_pct * c.v)))
                 / vp.daily_round) * vp.daily_round)::bigint,
         updated_at = now()
  from calc c where c.id = r.id;
  get diagnostics n = row_count;

  insert into public.rider_value_history (rider_id, day, value)
  select id, today, market_value from public.rider where active
  on conflict (rider_id, day) do update set value = excluded.value;
  insert into public.job_state (key, last_day) values ('rider_values', today)
  on conflict (key) do update set last_day = excluded.last_day, updated_at = now();
  return n;
end $$;

create or replace function public.create_league(p_name text, p_team_name text, p_settings jsonb default '{}',
                                     p_country text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  s jsonb := coalesce(p_settings, '{}');
  v_id uuid;
begin
  if auth.uid() is null then raise exception 'Inicia sesión para crear una liga'; end if;
  insert into public.league (name, admin_id, invite_code, max_riders, calendar_depth, market_size, market_hour,
                             clauses_enabled, payout_mode, payout_per_point, payout_by_position, next_market_at,
                             scoring_system, wt_split)
  values (trim(p_name), auth.uid(), public.gen_invite_code(),
          coalesce((s->>'max_riders')::smallint, 22),
          coalesce((s->>'calendar_depth')::smallint, 2),
          coalesce((s->>'market_size')::smallint, 10),
          coalesce((s->>'market_hour')::smallint, 8),
          coalesce((s->>'clauses_enabled')::boolean, true),
          coalesce((s->>'payout_mode')::public.payout_mode, 'per_point'),
          coalesce((s->>'payout_per_point')::integer, 100),
          coalesce((select array_agg(x::bigint) from jsonb_array_elements_text(s->'payout_by_position') x), '{}'),
          public.app_now(),
          coalesce(s->>'scoring_system', 'cyclonomy'),
          coalesce((s->>'wt_split')::boolean, true))
  returning id into v_id;
  -- la semana de creación cuenta como ya iniciada: el primer cambio de semana es el próximo lunes
  insert into public.week_run (league_id, week_start) values (v_id, public.week_start(public.app_now()));
  perform public.add_member(v_id, auth.uid(), trim(p_team_name), p_country);
  perform public.resolve_market(v_id);          -- primer mercado
  return v_id;
end $$;

-- Cómo funciona cada sistema (para elegirlo al crear la liga): por grupo, sus carreras del año y sus tablas
create or replace function public.get_scoring_systems(p_season integer default null) returns jsonb
language sql stable security definer set search_path = public as $fn$
  with season as (
    -- por defecto, la temporada del calendario del juego (la última cargada)
    select coalesce(p_season, (select max(r.season) from public.race r)) y
  ), groups as (
    select sch.scheme, public.scoring_group(sch.scheme, r.category, r.pcs_slug) grp, r.name, r.start_date
    from public.race r cross join season
    cross join (values ('cyc'), ('cyc_wt'), ('uci')) sch(scheme)
    where r.season = season.y
  )
  select jsonb_object_agg(sch.scheme, (
    select coalesce(jsonb_agg(jsonb_build_object(
             'grp', g.grp,
             'races', (select coalesce(jsonb_agg(distinct x.name), '[]'::jsonb) from groups x
                       where x.scheme = sch.scheme and x.grp = g.grp),
             'rules', (select jsonb_object_agg(k.kind, k.pts) from (
                         select sp.kind, jsonb_agg(sp.points order by sp.position) pts
                         from public.scoring_points sp where sp.scheme = sch.scheme and sp.grp = g.grp
                         group by sp.kind) k))
           order by (select max(sp.points) from public.scoring_points sp
                     where sp.scheme = sch.scheme and sp.grp = g.grp) desc), '[]'::jsonb)
    from (select distinct sp.grp from public.scoring_points sp where sp.scheme = sch.scheme) g))
  from (values ('cyc'), ('cyc_wt'), ('uci')) sch(scheme)
$fn$;

revoke all on function public.get_scoring_systems(integer), public.league_scheme(uuid) from public, anon;
grant execute on function public.get_scoring_systems(integer) to authenticated;
revoke all on function public.create_league(text, text, jsonb, text) from public, anon;
grant execute on function public.create_league(text, text, jsonb, text) to authenticated;
