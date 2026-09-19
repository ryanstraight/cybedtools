// Click-to-sort behavior for tables tagged class="sortable".
// Numeric columns (with optional commas) sort numerically; everything else
// sorts as case-insensitive strings. Click toggles asc/desc on the active
// column and clears state on others.
(function () {
  function isNumeric(s) {
    if (s === '' || s === null) return false;
    var n = parseFloat(s.replace(/,/g, ''));
    return !isNaN(n) && isFinite(n);
  }

  function compare(a, b, asc) {
    if (isNumeric(a) && isNumeric(b)) {
      var an = parseFloat(a.replace(/,/g, ''));
      var bn = parseFloat(b.replace(/,/g, ''));
      return asc ? an - bn : bn - an;
    }
    var al = a.toLowerCase();
    var bl = b.toLowerCase();
    if (al < bl) return asc ? -1 : 1;
    if (al > bl) return asc ? 1 : -1;
    return 0;
  }

  function attachSort(table) {
    var headers = table.querySelectorAll('thead th');
    headers.forEach(function (th, idx) {
      th.classList.add('sortable-th');
      th.addEventListener('click', function () {
        var asc = th.dataset.sortAsc !== 'true';
        var tbody = table.querySelector('tbody');
        var rows = Array.from(tbody.querySelectorAll('tr'));

        rows.sort(function (rowA, rowB) {
          var a = (rowA.children[idx].textContent || '').trim();
          var b = (rowB.children[idx].textContent || '').trim();
          return compare(a, b, asc);
        });

        headers.forEach(function (other) {
          delete other.dataset.sortAsc;
          other.classList.remove('sort-asc', 'sort-desc');
        });
        th.dataset.sortAsc = asc;
        th.classList.add(asc ? 'sort-asc' : 'sort-desc');

        rows.forEach(function (row) { tbody.appendChild(row); });
      });
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('table.sortable').forEach(attachSort);
  });
})();
