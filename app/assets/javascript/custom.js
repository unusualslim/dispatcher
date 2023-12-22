//import Sortable from 'sortablejs';

document.addEventListener('DOMContentLoaded', () => {
  
  const driverNotes = document.querySelectorAll('.driver-note');

  driverNotes.forEach((note) => {
    const link = note.querySelector('.links');
    const dispatchId = note.dataset.cardId;
    note.addEventListener('dragstart', (event) => {
      const dispatchId = note.dataset.cardId;
      event.dataTransfer.setData('text/plain', 'dragging');
      event.dataTransfer.setData('dispatchId', dispatchId);
      console.log("Card dragged: ", note)
      note.dataset.needs_updating = true;
    });

    // Update href attribute with the dispatch ID
    link.href = `/dispatches/${dispatchId}`;
  });

  const columns = document.querySelectorAll('.custom-column');

  columns.forEach((column) => {
    new Sortable(column, {
      group: 'column',
      animation: 150,
      onEnd(evt) {
        evt.item.style.backgroundColor = '';

        // Find the nearest .driver-note element and add the class if it exists
        const driverNote = evt.item.closest('.driver-note');
        if (driverNote) {
          driverNote.classList.add('driver-note');
        }
      },
    });

    const driverNotesList = column.querySelector('.dispatch-list');
      new Sortable(driverNotesList, {
        group: 'column',
        animation: 150,
        draggable: ".driver-note",
        onStart(evt) {
          evt.item.style.backgroundColor = 'lightgreen';
        },
        onEnd(evt) {
          evt.item.style.backgroundColor = 'lightgreen';
          const driverNote = evt.item.closest('.driver-note');
          // if (driverNote) {
          //   driverNote.classList.add('driver-note');
          // }
          console.log(`Column with driver ID: ${column.dataset.driverId}`);
          console.log(`Card with dispatch ID: ${column.dataset.cardId}`);
        },
      });
  });
    //For the unassigned dispatches in the left-most column
    const unassigned_dispatches = document.querySelectorAll('.dispatches');
    unassigned_dispatches.forEach((dispatch) => {

    new Sortable(dispatch, {
      group: 'column',
      animation: 150,
      draggable: ".driver-note",
      onStart(evt) {
        evt.item.style.backgroundColor = 'lightgreen';
      },
      onEnd(evt){
        evt.item.style.backgroundColor = 'lightgreen';
        evt.item.classList.add('.driver-note');
        console.log(`Column with driver ID: ${dispatch.dataset.driverId}`);
        console.log(`Card with dispatch ID: ${dispatch.dataset.cardId}`);
      }
    })
  })

  const btn = document.getElementById('updateDriverNotes');
    
  btn.addEventListener('click', () => {
    btn.disabled = true;

      // Update notes in the first column (dispatches)
      const firstColumnDispatches = document.querySelectorAll('.dispatches .driver-note');
      firstColumnDispatches.forEach((note) => {
          if (note.dataset.needsUpdating === 'true') {
              const dispatchId = note.dataset.cardId;

              // Send a PATCH request to update the note's driverId in the database to null
              fetch(`/dispatches/${dispatchId}`, {
                  method: 'PATCH',
                  headers: {
                      'Content-Type': 'application/json',
                      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
                  },
                  body: JSON.stringify({ driver_id: null }),
              })
              .then((response) => {
                  if (!response.ok) {
                      throw new Error('Network response was not ok');
                  }
              })
              .catch((error) => {
                  console.error('Error updating dispatch:', error);
              });
          }
      });


      const columns = document.querySelectorAll('.custom-column');
      console.log("How many custom-columns: ",columns)
      columns.forEach((column) => {
          const driverId = column.dataset.driverId;

          const driverNotes = column.querySelectorAll('.driver-note');
          driverNotes.forEach((note) => {
              const needsUpdating = note.dataset.needs_updating === 'true';
              if (needsUpdating) {
                  note.dataset.driverId = driverId;

                  const dispatchId = note.dataset.cardId;
                  fetch(`/dispatches/${dispatchId}`, {
                      method: 'PATCH',
                      headers: {
                          'Content-Type': 'application/json',
                          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
                      },
                      body: JSON.stringify({ driver_id: driverId }),
                  })
                  .then((response) => {
                      if (!response.ok) {
                          throw new Error('Network response was not ok');
                      }
                  })
                  .catch((error) => {
                      console.error('Error updating dispatch:', error);
                  });
              }
          });
      });
      setTimeout(() => {
        btn.disabled = false;
        location.reload();
    }, 1000);
  });
  const trashCan = document.getElementById('sticky-trash-can');

  trashCan.addEventListener('dragover', (event) => {
    event.preventDefault();

    
  });

  trashCan.addEventListener('drop', async (event) => {
    event.preventDefault();
    const dispatchId = event.dataTransfer.getData('dispatchId');
  
    // Perform an action to delete the dispatch with the ID
    console.log('Drop Event:', event);
    console.log('Dispatch ID:', dispatchId);
    await deleteDispatch(dispatchId);
  
    // Reload the page after the action is completed
    location.reload();
  });

  function deleteDispatch(dispatchId) {
    console.log("DispatchID in deleteDispatch: ",dispatchId)
    fetch(`/dispatches/${dispatchId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
      },
      body: JSON.stringify({ status: 'deleted' }), // Update the status to 'deleted'
    })
    .then((response) => {
      location.reload();
      if (!response.ok) {
        throw new Error('Network response was not ok');
      }
      const deletedDispatch = document.querySelector(`[data-card-id="${dispatchId}"]`);
      if (deletedDispatch) {
        deletedDispatch.remove();
      }
    })
    .catch((error) => {
      console.error('Error deleting dispatch:', error);
    });
  }
});

function updateDispatchDriver(dispatchId, newDriverId) {
  fetch(`/dispatches/${dispatchId}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
    },
    body: JSON.stringify({ driver_id: newDriverId }),
  })
    .then((response) => {
      if (!response.ok) {
        throw new Error('Network response was not ok');
      }
      return response.json();
    })
    .then((data) => {
      console.log('Dispatch updated successfully:', data);
    })
    .catch((error) => {
      console.error('Error updating dispatch:', error);
    });
}