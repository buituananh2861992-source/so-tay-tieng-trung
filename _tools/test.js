window.__log = [];
window.addEventListener("error", e => __log.push("ERR " + e.message + " @" + e.lineno));
setTimeout(() => {
  const L = m => __log.push(m);
  const tryIt = (name, f) => { try { f(); L("ok " + name); } catch (e) { L("FAIL " + name + ": " + e.message + " | " + String(e.stack || "").split("\n").slice(1, 3).join(" ")); } };
  TABS.forEach(([id]) => tryIt("tab " + id, () => showTab(id)));
  tryIt("dict", () => {
    showTab("tudien");
    const t0 = performance.now();
    ["xiexie", "jingji", "cảm ơn", "kinh tế", "經濟", "ni3hao3", "huanjing"].forEach(q => { $("#dSearch").value = q; renderDict(); const c = $("#dGrid .card"); L("  " + q + " -> " + $$("#dGrid .card").length + " first " + (c ? c.dataset.w : "-")); });
    L("  search ms avg " + Math.round((performance.now() - t0) / 7));
    $("#dSearch").value = ""; renderDict(); L("  cards shown " + $$("#dGrid .card").length + " more btn " + !!$("#dMore"));
    $("#dMore").click(); L("  after more " + $$("#dGrid .card").length);
    dLv = "7"; renderDict(); L("  lv7 count text " + $("#dCount").textContent);
    dLv = "all";
  });
  tryIt("openWord auto", () => { openWord("经济"); L("  sheet has note " + /CVDICT/.test($("#sheet").innerHTML)); closeSheet(); });
  tryIt("review new HSK3", () => { S.set.newSrc = "3"; startReview(); L("  first card lv " + (R.q[0] ? DICT.get(R.q[0]).lv : "-")); S.set.newSrc = "all"; R = null; });
  tryIt("idioms", () => { showTab("thanhngu"); L("  idioms " + $$("#iList .ph").length); $("#iSearch").value = "ech"; renderIdioms(); L("  search ech " + $$("#iList .ph").length); $("#iSearch").value = ""; renderIdioms(); });
  tryIt("practice tn", () => { showTab("luyentap"); P.mode = "tn"; newPractice(); renderPQ(); L("  tn opts " + $$("#pBox .opt").length); $("#pBox .opt").click(); L("  fb " + $("#pFb").textContent.slice(0, 60)); });
  tryIt("exams", () => {
    showTab("thithu");
    ["2", "3"].forEach(sys => {
      X.sys = sys; X.run = null;
      Object.keys(EXS()).map(Number).forEach(lv => {
        X.lv = lv; X.run = null; renderExam(); $("#xStart").click();
        const r = X.run;
        r.qs.forEach((q, i) => {
          r.i = i; renderExamQ();
          if (q.ty === "tf" || q.ty === "pic" || q.ty === "mcq") r.ans[i] = q.a;
          else if (q.ty === "order") r.ans[i] = [...q.w.keys()].sort((x, y) => q.a[0].indexOf(q.w[x]) - q.a[0].indexOf(q.w[y]));
          else if (q.ty === "char") r.ans[i] = q.a;
          else if (q.ty === "free") { r.read[i] = true; renderExamQ(); r.ans[i] = q.model; }
        });
        r.i = r.qs.length - 1; renderExamQ(); $("#xSubmit").click(); if (!r.done && $("#xSubmitYes")) $("#xSubmitYes").click();
        const sc = $("#xArea .result .score"), vd = $("#xArea .verdict");
        L("  " + lvName() + " " + (sc ? sc.textContent : "?") + " | " + (vd ? vd.textContent : "?") + " | items " + $$(".x-item").length);
      });
    });
    X.run = null; X.sys = "3"; X.lv = 1; renderExam();
  });
  tryIt("practice modes", () => { PMODES.forEach(([m]) => { P.mode = m; newPractice(); renderPQ(); }); });
  tryIt("pron", () => { showTab("phatam"); const h = $("#tHv .hv-stat"); L("  hv " + (h ? h.textContent.slice(0, 80) : "")); });
  tryIt("trad", () => { S.set.script = "t"; renderAll(); TABS.forEach(([id]) => showTab(id)); S.set.script = "s"; renderAll(); });
  tryIt("home", () => showTab("homnay"));
  L("words " + WORDS.length + " idioms " + IDIOMS.length);
  // Kịch bản phần nghe để thu âm
  const seen = {}, out = [];
  [EXAMS, EXAMS3].forEach(E => Object.values(E).forEach(ex => ex.qs.forEach(q => {
    if (!q.say) return;
    const k = scriptKey(q.say); if (seen[k]) return; seen[k] = 1;
    out.push({ k, lines: (Array.isArray(q.say) ? q.say : [q.say]).map(l => { const m = l.match(/^(男|女|问)：([\s\S]*)$/); return { w: m ? m[1] : "", t: m ? m[2] : l }; }) });
  })));
  L("scripts " + out.length);
  const pre = document.createElement("pre"); pre.id = "testlog"; pre.textContent = __log.join("\n"); document.body.appendChild(pre);
  const pre2 = document.createElement("pre"); pre2.id = "scripts"; pre2.textContent = JSON.stringify(out); document.body.appendChild(pre2);
}, 1500);
