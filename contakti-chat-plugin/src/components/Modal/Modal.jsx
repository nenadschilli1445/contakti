import Button from 'react-bootstrap/Button';
import Modal from 'react-bootstrap/Modal';


function ModalComponent({show, handleClose, haveQuery, data}) {
    console.log("data inside ModalComponent:", data);
    return (
        <Modal show={show} onHide={handleClose}>
            <Modal.Header closeButton>
                <Modal.Title>{data?.chat_confirmation}</Modal.Title>
            </Modal.Header>
            <Modal.Body>{data?.chat_query}</Modal.Body>
            <Modal.Footer>
                <Button variant="secondary" onClick={handleClose}>
                    {data?.chat_quit}
                </Button>
                <Button variant="secondary" onClick={haveQuery}>
                {data?.chat_agree}
                </Button>
            </Modal.Footer>
        </Modal>
    );
}

export default ModalComponent;
